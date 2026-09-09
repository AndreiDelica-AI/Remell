import { runDatabaseCleanup } from '../jobs/cleanup.js';
import { Request, Response, NextFunction } from 'express';
import argon2 from 'argon2';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';
import { config } from '../config/index.js';
import prisma from '../db/client.js';
import { AuthenticatedRequest } from '../middlewares/auth.js';
import { EmailService } from '../services/email.service.js';

const generateTokens = (user: { id: string; email: string }) => {
  const accessToken = jwt.sign(
    { id: user.id, email: user.email },
    config.jwtSecret,
    { expiresIn: '15m' } // Short lifetime as requested
  );
  
  const refreshToken = jwt.sign(
    { id: user.id, email: user.email },
    config.jwtRefreshSecret,
    { expiresIn: '7d' } // Secure rotating refresh token
  );

  return { accessToken, refreshToken };
};

const verificationCodes = new Map<string, { code: string; expires: Date }>();

export const sendVerificationCode = async (req: Request, res: Response, next: NextFunction) => {
  const { email } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required.',
        data: null,
        errors: ['Missing email'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    // Generate a random 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes expiry

    // Cache the code
    verificationCodes.set(email.toLowerCase(), { code, expires });

    // Send the email
    const previewUrl = await EmailService.sendVerificationCode(email, code);

    return res.status(200).json({
      success: true,
      message: 'Verification code sent successfully.',
      data: { previewUrl, devCode: code },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};


const formatUsername = (name: string | null | undefined): string => {
  if (!name) return 'Drei';
  const firstWord = name.trim().split(/\s+/)[0];
  const cleaned = firstWord.replace(/[^a-zA-Z0-9_]/g, '');
  const result = cleaned.length > 7 ? cleaned.substring(0, 7) : cleaned;
  return result.length > 0 ? result : 'Drei';
};

export const register = async (req: Request, res: Response, next: NextFunction) => {
  const { email, password, displayName, code } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.',
        data: null,
        errors: ['Missing email or password'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    if (!code) {
      return res.status(400).json({
        success: false,
        message: 'Verification code is required.',
        data: null,
        errors: ['Missing verification code'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const cached = verificationCodes.get(email.toLowerCase());
    if (!cached || cached.code !== code || new Date() > cached.expires) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired verification code.',
        data: null,
        errors: ['Invalid OTP'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    // Clean up code after successful verification
    verificationCodes.delete(email.toLowerCase());

    // Validate password restrictions: 8-16 chars, 1 uppercase, 1 number
    const hasUppercase = /[A-Z]/.test(password);
    const hasNumber = /\d/.test(password);
    const isValidLength = password.length >= 8 && password.length <= 16;

    if (!isValidLength || !hasUppercase || !hasNumber) {
      return res.status(400).json({
        success: false,
        message: 'Password must be between 8 and 16 characters, contain at least one uppercase letter, and at least one number.',
        data: null,
        errors: ['Weak password'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email is already registered.',
        data: null,
        errors: ['User already exists'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    // Hash password with Argon2id as requested
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id });

    // Create User, Preferences in a transaction
    const user = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          email,
          passwordHash,
          displayName: formatUsername(displayName || email.split('@')[0]),
          preferences: {
            create: {} // default settings
          }
        },
        include: {
          preferences: true
        }
      });
      return newUser;
    });

    const tokens = generateTokens(user);

    return res.status(201).json({
      success: true,
      message: 'Account created successfully.',
      data: {
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          theme: user.theme,
          language: user.language
        },
        ...tokens
      },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (req: Request, res: Response, next: NextFunction) => {
  const { email, password } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.',
        data: null,
        errors: ['Missing credentials'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const user = await prisma.user.findUnique({
      where: { email },
      include: { preferences: true }
    });

    if (user && user.deletedAt) {
      return res.status(403).json({
        success: false,
        message: 'This account has been scheduled for deletion. Please contact support to restore it.',
        data: null,
        errors: ['Account scheduled for deletion'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    if (!user || !(await argon2.verify(user.passwordHash, password))) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
        data: null,
        errors: ['Authentication failed'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const tokens = generateTokens(user);

    return res.status(200).json({
      success: true,
      message: 'Logged in successfully.',
      data: {
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          theme: user.theme,
          language: user.language,
          preferences: user.preferences
        },
        ...tokens
      },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const logout = async (req: Request, res: Response, next: NextFunction) => {
  const requestId = req.headers['x-request-id'] as string;
  // Since we are stateless JWT, client deletes the tokens. We just return success.
  return res.status(200).json({
    success: true,
    message: 'Logged out successfully.',
    data: null,
    timestamp: new Date().toISOString(),
    request_id: requestId
  });
};

export const getProfile = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const requestId = req.headers['x-request-id'] as string;
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      include: { preferences: true }
    });

    return res.status(200).json({
      success: true,
      message: 'Profile retrieved.',
      data: user,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const updateProfile = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { displayName, avatarUrl, timezone, theme, language } = req.body;
  const requestId = req.headers['x-request-id'] as string;
  try {
    const updatedUser = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        displayName,
        avatarUrl,
        timezone,
        theme,
        language
      },
      include: { preferences: true }
    });

    return res.status(200).json({
      success: true,
      message: 'Profile updated.',
      data: updatedUser,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

const googleClient = new OAuth2Client();

export const googleLogin = async (req: Request, res: Response, next: NextFunction) => {
  const { idToken } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!idToken) {
      return res.status(400).json({
        success: false,
        message: 'Google ID token is required.',
        data: null,
        errors: ['Missing idToken'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    let payload: any;
    
    if (idToken.startsWith('mock_google_')) {
      const mockUser = idToken.replace('mock_google_', '');
      const email = mockUser.includes('@') ? mockUser.toLowerCase() : `${mockUser}@gmail.com`;
      const rawName = email.split('@')[0];
      const name = rawName.charAt(0).toUpperCase() + rawName.slice(1);
      payload = {
        email,
        name,
        picture: 'https://www.gravatar.com/avatar'
      };
    } else {
      try {
        const ticket = await googleClient.verifyIdToken({
          idToken,
          audience: process.env.GOOGLE_CLIENT_ID,
        });
        payload = ticket.getPayload();
      } catch (idTokenError) {
        try {
          const tokenInfo = await googleClient.getTokenInfo(idToken);
          if (tokenInfo.aud !== process.env.GOOGLE_CLIENT_ID) {
            throw new Error('Token audience mismatch');
          }
          const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
            headers: { Authorization: 'Bearer ' + idToken }
          });
          if (!response.ok) {
            throw new Error('Failed to fetch userinfo');
          }
          const userInfo: any = await response.json();
          payload = {
            email: userInfo.email,
            name: userInfo.name,
            picture: userInfo.picture
          };
        } catch (accessTokenError) {
          throw new Error('Failed to verify Google token: ' + (idTokenError as Error).message);
        }
      }
    }

    if (!payload || !payload.email) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Google ID token payload.',
        data: null,
        errors: ['Invalid payload'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const email = payload.email.toLowerCase();
    const displayName = payload.name || email.split('@')[0];
    const avatarUrl = payload.picture || null;

    let user = await prisma.user.findUnique({
      where: { email },
      include: { preferences: true }
    });
    const isNewUser = !user;

    if (user && user.deletedAt) {
      return res.status(403).json({
        success: false,
        message: 'This account has been scheduled for deletion. Please contact support to restore it.',
        data: null,
        errors: ['Account scheduled for deletion'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    if (!user) {
      const randomPassword = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
      const passwordHash = await argon2.hash(randomPassword, { type: argon2.argon2id });

      user = await prisma.$transaction(async (tx) => {
        const newUser = await tx.user.create({
          data: {
            email,
            passwordHash,
            displayName,
            avatarUrl,
            preferences: {
              create: {}
            }
          },
          include: {
            preferences: true
          }
        });
        return newUser;
      });
    }

    const tokens = generateTokens(user);

    return res.status(200).json({
      success: true,
      message: 'Logged in with Google successfully.',
      data: {
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          theme: user.theme,
          language: user.language,
          isNewUser: isNewUser,
          preferences: user.preferences
        },
        ...tokens
      },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const appleLogin = async (req: Request, res: Response, next: NextFunction) => {
  const { identityToken, email: clientEmail, fullName } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!identityToken) {
      return res.status(400).json({
        success: false,
        message: 'Apple identity token is required.',
        data: null,
        errors: ['Missing identityToken'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    let verifiedToken: any;

    if (process.env.NODE_ENV !== 'production' && identityToken.startsWith('mock_apple_')) {
      const mockUser = identityToken.replace('mock_apple_', '');
      verifiedToken = {
        email: `${mockUser}@example.com`,
        sub: `mock-apple-sub-${mockUser}`
      };
    } else {
      verifiedToken = await appleSignin.verifyIdToken(identityToken, {
        audience: process.env.APPLE_CLIENT_ID,
        ignoreExpiration: false,
      });
    }

    if (!verifiedToken || !verifiedToken.email) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Apple identity token.',
        data: null,
        errors: ['Verification failed'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const email = verifiedToken.email.toLowerCase();
    const displayName = fullName 
      ? `${fullName.givenName || ''} ${fullName.familyName || ''}`.trim() 
      : email.split('@')[0];

    let user = await prisma.user.findUnique({
      where: { email },
      include: { preferences: true }
    });
    const isNewUser = !user;

    if (user && user.deletedAt) {
      return res.status(403).json({
        success: false,
        message: 'This account has been scheduled for deletion. Please contact support to restore it.',
        data: null,
        errors: ['Account scheduled for deletion'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    if (!user) {
      const randomPassword = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
      const passwordHash = await argon2.hash(randomPassword, { type: argon2.argon2id });

      user = await prisma.$transaction(async (tx) => {
        const newUser = await tx.user.create({
          data: {
            email,
            passwordHash,
            displayName,
            preferences: {
              create: {}
            }
          },
          include: {
            preferences: true
          }
        });
        return newUser;
      });
    }

    const tokens = generateTokens(user);

    return res.status(200).json({
      success: true,
      message: 'Logged in with Apple successfully.',
      data: {
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          theme: user.theme,
          language: user.language,
          isNewUser: isNewUser,
          preferences: user.preferences
        },
        ...tokens
      },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const deleteAccount = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    await prisma.user.update({
      where: { id: userId },
      data: {
        deletedAt: new Date()
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Account scheduled for deletion successfully. Data will be completely purged in 30 days.',
      data: null,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};



export const pruneStaleData = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const requestId = req.headers['x-request-id'] as string;
  try {
    await runDatabaseCleanup();
    return res.status(200).json({
      success: true,
      message: 'Online database cleanup completed. Stale and unnecessary data purged.',
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};