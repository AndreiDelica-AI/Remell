import 'dart:io' show Platform;
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/config/auth_config.dart';
import '../../../core/config/legal_texts.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/time_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isSignUp = false;
  String? _errorMessage;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _verificationSent = false;
  final _codeController = TextEditingController();
  int _countdownSeconds = 60;
  Timer? _countdownTimer;

  late final _dio = Dio(BaseOptions(
    baseUrl: ApiClient.resolvedBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  void _startCountdown() {
    _countdownSeconds = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == 0) {
        setState(() {
          _countdownTimer?.cancel();
        });
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _validateAndSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'You must agree to the Terms & Conditions and Privacy Policy.';
      });
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final rawName = _nameController.text.trim();
final firstWord = rawName.split(RegExp(r'\s+')).first;
final cleaned = firstWord.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
final name = cleaned.length > 7 ? cleaned.substring(0, 7) : cleaned;
    final code = _codeController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email.';
      });
      return;
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password.';
      });
      return;
    }

    if (_isSignUp) {
      final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      final hasNumber = RegExp(r'\d').hasMatch(password);
      final isValidLength = password.length >= 8 && password.length <= 16;
      if (!isValidLength || !hasUppercase || !hasNumber) {
        setState(() {
          _errorMessage = 'Password must be 8-16 characters, contain at least one uppercase letter, and at least one number.';
        });
        return;
      }
    } else {
      if (password.length < 6) {
        setState(() {
          _errorMessage = 'Password must be at least 6 characters.';
        });
        return;
      }
    }

    if (_isSignUp && name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name.';
      });
      return;
    }

    if (_isSignUp && _verificationSent && code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit verification code sent to your email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool success = false;
    try {
      Response response;
      if (_isSignUp) {
        if (!_verificationSent) {
          // Step 1: Send verification code
          response = await _dio.post('/auth/send-code', data: {
            'email': email,
          });

          setState(() {
            _isLoading = false;
          });

          if (response.statusCode == 200) {
            setState(() {
              _verificationSent = true;
            });
            _startCountdown();
            
            // Check if backend returned ethereal mailbox link
            final previewUrl = response.data['data']?['previewUrl'] as String?;
            final isThemeDark = Theme.of(context).brightness == Brightness.dark;
            final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(LucideIcons.mailCheck, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        previewUrl != null
                            ? 'Code sent! View test inbox at: $previewUrl'
                            : 'Verification code sent to $email',
                        style: GoogleFonts.inter(color: primaryTextColor),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 12),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.blueAccent,
                  onPressed: () {},
                ),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: primaryTextColor.withOpacity(0.08), width: 1.5),
                ),
                backgroundColor: isThemeDark 
                    ? const Color(0xFF1E293B).withOpacity(0.95) 
                    : Colors.white.withOpacity(0.95),
              ),
            );
          } else {
            setState(() {
              _errorMessage = response.data['message'] ?? 'Failed to send verification code.';
            });
          }
          return;
        } else {
          // Step 2: Register with verification code
          response = await _dio.post('/auth/register', data: {
            'email': email,
            'password': password,
            'displayName': name,
            'code': code,
          });
        }
      } else {
        response = await _dio.post('/auth/login', data: {
          'email': email,
          'password': password,
        });
      }

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        final token = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final user = data['user'] as Map<String, dynamic>;

        saveAuthSession(token, user, refreshToken: refreshToken);
        ref.read(authTokenProvider.notifier).state = token;
        ref.read(authUserProvider.notifier).state = user;

        success = true;
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Authentication failed.';
        });
      }
    } on DioException catch (e) {
      debugPrint('[Login Error] DioException: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
      String msg = 'Something went wrong. Please try again.';
      if (e.response != null && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        msg = 'Cannot connect to database server. Please check backend connection.';
      }
      setState(() {
        _errorMessage = msg;
      });
    } catch (e, stack) {
      debugPrint('[Login Error] Generic Exception: ${e.toString()}\n$stack');
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred.';
      });
    }

    if (success) {
      context.go('/home');
    }
  }

  void _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final response = await _dio.post('/auth/send-code', data: {
        'email': email,
      });

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        _startCountdown();
        final previewUrl = response.data['data']?['previewUrl'] as String?;
        final isThemeDark = Theme.of(context).brightness == Brightness.dark;
        final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.mailCheck, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previewUrl != null
                        ? 'New code sent! View test inbox at: $previewUrl'
                        : 'A new code has been sent to your email.',
                    style: GoogleFonts.inter(color: primaryTextColor),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 12),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primaryTextColor.withOpacity(0.08), width: 1.5),
            ),
            backgroundColor: isThemeDark 
                ? const Color(0xFF1E293B).withOpacity(0.95) 
                : Colors.white.withOpacity(0.95),
          ),
        );
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to resend code.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect. Please try again.';
      });
    }
  }

  Widget buildPasswordGuide() {
    final passwordText = _passwordController.text;
    final lengthOk = passwordText.length >= 8 && passwordText.length <= 16;
    final upperOk = RegExp(r'[A-Z]').hasMatch(passwordText);
    final numOk = RegExp(r'\d').hasMatch(passwordText);

    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final requirementColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Password requirements:',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: requirementColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildRequirementRow('8 to 16 characters long', lengthOk),
        const SizedBox(height: 4),
        _buildRequirementRow('At least one uppercase letter (caps lock)', upperOk),
        const SizedBox(height: 4),
        _buildRequirementRow('At least one numeric digit', numOk),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool isSatisfied) {
    return Row(
      children: [
        Icon(
          isSatisfied ? LucideIcons.checkCircle : LucideIcons.circle,
          size: 14,
          color: isSatisfied ? const Color(0xFF10B981) : Colors.grey.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isSatisfied 
                ? const Color(0xFF10B981) 
                : Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF94A3B8).withOpacity(0.8) 
                    : const Color(0xFF6B7280).withOpacity(0.8),
            fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _socialLogin(String platform) async {
    setState(() {
      _errorMessage = null;
    });

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'You must agree to the Terms & Conditions and Privacy Policy.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool success = false;
    try {
      Response response;
      if (platform == 'google') {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: kIsWeb ? AuthConfig.googleClientId : null,
          scopes: ['email', 'profile', 'openid'],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User canceled or closed popup
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final String? idToken = googleAuth.idToken ?? googleAuth.accessToken;

        if (idToken == null || idToken.isEmpty) {
          throw Exception('Google OAuth succeeded, but no ID token was retrieved.');
        }

        response = await _dio.post('/auth/google', data: {
          'idToken': idToken,
        });
      } else {
        String identityToken;
        Map<String, dynamic>? fullName;

        if (AuthConfig.useAppleMockFallback) {
          debugPrint('[Auth] Using Mock Apple Sign-In Fallback');
          identityToken = 'mock_apple_john';
          fullName = {
            'givenName': 'John',
            'familyName': 'Andrei',
          };
        } else {
          final credential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            webAuthenticationOptions: kIsWeb || (!kIsWeb && !Platform.isIOS && !Platform.isMacOS)
                ? WebAuthenticationOptions(
                    clientId: AuthConfig.appleServiceId,
                    redirectUri: Uri.parse(AuthConfig.appleRedirectUri),
                  )
                : null,
          );

          if (credential.identityToken == null) {
            throw Exception('Apple login succeeded, but no identity token was retrieved.');
          }
          identityToken = credential.identityToken!;
          if (credential.givenName != null || credential.familyName != null) {
            fullName = {
              if (credential.givenName != null) 'givenName': credential.givenName,
              if (credential.familyName != null) 'familyName': credential.familyName,
            };
          }
        }

        response = await _dio.post('/auth/apple', data: {
          'identityToken': identityToken,
          if (fullName != null) 'fullName': fullName,
        });
      }

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        final token = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final user = data['user'] as Map<String, dynamic>;

        saveAuthSession(token, user, refreshToken: refreshToken);
        ref.read(authTokenProvider.notifier).state = token;
        ref.read(authUserProvider.notifier).state = user;

        success = true;
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Authentication failed.';
        });
      }
    } on DioException catch (e) {
      debugPrint('[Login Error] DioException: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
      String msg = 'Something went wrong. Please try again.';
      if (e.response != null && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      setState(() {
        _errorMessage = msg;
      });
    } catch (e, stack) {
      debugPrint('[Login Error] Generic Exception: ' + e.toString() + '\n' + stack.toString());
      final errStr = e.toString().toLowerCase();
      final isPopupClosed = errStr.contains('popup_closed') ||
          errStr.contains('popup_closed_by_user') ||
          errStr.contains('popup_blocked') ||
          errStr.contains('user_cancelled') ||
          errStr.contains('closed_by_user') ||
          errStr.contains('canceled') ||
          errStr.contains('cancelled') ||
          errStr.contains('access_denied');

      setState(() {
        _isLoading = false;
        if (isPopupClosed) {
          _errorMessage = null;
        } else {
          final errMessage = e.toString();
          if (errMessage.contains('Exception:')) {
            _errorMessage = errMessage.replaceAll('Exception: ', '');
          } else {
            _errorMessage = 'Sign-in was not completed: $errMessage';
          }
        }
      });
    }

    if (success) {
      context.go('/home');
    }
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Terms & Conditions',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Text(
                LegalTexts.termsAndConditions,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Privacy Policy',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Text(
                LegalTexts.privacyPolicy,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextFieldContainer({required Widget child, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF1F5F9).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.06),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final buttonBgColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final buttonTextColor = isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
    final dividerColor = isThemeDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TimeOfDayBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, child) {
                return Opacity(
                  opacity: animValue,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - animValue)),
                    child: child,
                  ),
                );
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                decoration: BoxDecoration(
                  color: isThemeDark 
                      ? const Color(0xFF1E293B).withOpacity(0.55) 
                      : Colors.white.withOpacity(0.80),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: primaryTextColor.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isThemeDark ? 0.3 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Logo & App Title side-by-side
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/logo_transparent.png',
                                height: 60,
                                width: 60,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.memory, size: 30, color: Theme.of(context).colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'remell.',
                                      style: GoogleFonts.inter(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.2,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    Text(
                                      _isSignUp ? 'create an account to start.' : 'Remind. Recall. Remember.',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Inline Error Message
                          if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Sign Up Name input
                          if (_isSignUp) ...[
                            _buildTextFieldContainer(
                              context: context,
                              child: TextField(
                                controller: _nameController,
                                style: GoogleFonts.inter(fontSize: 15, color: primaryTextColor),
                                decoration: InputDecoration(
                                  hintText: 'Display name (max 7 chars)',
                                  hintStyle: GoogleFonts.inter(color: secondaryTextColor.withOpacity(0.4), fontSize: 15),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email input
                          _buildTextFieldContainer(
                            context: context,
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(fontSize: 15, color: primaryTextColor),
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: GoogleFonts.inter(color: secondaryTextColor.withOpacity(0.4), fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Password input
                          _buildTextFieldContainer(
                            context: context,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              onChanged: (val) => setState(() {}),
                              style: GoogleFonts.inter(fontSize: 15, color: primaryTextColor),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: GoogleFonts.inter(color: secondaryTextColor.withOpacity(0.4), fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          if (_isSignUp) buildPasswordGuide(),
                          
                          // Verification Code Input (OTP)
                          if (_isSignUp && _verificationSent) ...[
                            const SizedBox(height: 16),
                            _buildTextFieldContainer(
                              context: context,
                              child: TextField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Verification Code (6-digit)',
                                  hintStyle: GoogleFonts.inter(
                                    color: secondaryTextColor.withOpacity(0.4),
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _verificationSent = false;
                                      _codeController.clear();
                                      _countdownTimer?.cancel();
                                    });
                                  },
                                  child: Text(
                                    'Change email',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _countdownSeconds > 0
                                    ? Text(
                                        'Resend in ${_countdownSeconds}s',
                                        style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor),
                                      )
                                    : TextButton(
                                        onPressed: _resendCode,
                                        child: Text(
                                          'Resend Code',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          
                          // Terms Checkbox
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  onChanged: (val) {
                                    setState(() {
                                      _agreedToTerms = val ?? false;
                                    });
                                  },
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  side: BorderSide(color: secondaryTextColor.withOpacity(0.5)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'I agree to the ',
                                      style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showTermsDialog(context),
                                      child: Text(
                                        'Terms & Conditions',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' and ',
                                      style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showPrivacyDialog(context),
                                      child: Text(
                                        'Privacy Policy',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Submit button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _validateAndSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonBgColor,
                              foregroundColor: buttonTextColor,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              splashFactory: NoSplash.splashFactory,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(buttonTextColor),
                                    ),
                                  )
                                : Text(
                                    _isSignUp 
                                        ? (_verificationSent ? 'Verify & Create Account' : 'Send Verification Code') 
                                        : 'Continue with email',
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: dividerColor)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'or continue with',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor.withOpacity(0.5),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: dividerColor)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Social Buttons
                          OutlinedButton.icon(
                            onPressed: () => _socialLogin('google'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: dividerColor),
                              foregroundColor: primaryTextColor,
                              splashFactory: NoSplash.splashFactory,
                            ),
                            icon: const Icon(Icons.g_mobiledata, size: 24),
                            label: Text(
                              'Google',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Sign In / Sign Up Toggle Link
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _errorMessage = null;
                                });
                              },
                              style: TextButton.styleFrom(
                                splashFactory: NoSplash.splashFactory,
                                foregroundColor: secondaryTextColor,
                              ),
                              child: Text(
                                _isSignUp ? 'Already have an account? Sign in' : 'Don\'t have an account? Create one',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}







