import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config/index.js';
import prisma from '../db/client.js';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
  };
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access token required.',
      data: null,
      errors: ['No token provided'],
      timestamp: new Date().toISOString(),
      request_id: req.headers['x-request-id'] || 'req-unauth'
    });
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret) as { id: string; email: string };
    
    // Check if user exists
    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: { id: true, email: true }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User no longer exists.',
        data: null,
        errors: ['User not found'],
        timestamp: new Date().toISOString(),
        request_id: req.headers['x-request-id'] || 'req-unauth'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(403).json({
      success: false,
      message: 'Invalid or expired access token.',
      data: null,
      errors: ['Token validation failed'],
      timestamp: new Date().toISOString(),
      request_id: req.headers['x-request-id'] || 'req-unauth'
    });
  }
};
