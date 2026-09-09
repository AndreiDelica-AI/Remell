class AuthConfig {
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '505668352242-4qgrmkc7avlp3ltnfphf2skqvdbat1th.apps.googleusercontent.com',
  );

  static const String appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: 'YOUR_APPLE_SERVICE_ID',
  );

  static const String appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://your-backend.com/auth/apple/callback',
  );

  // Real Google OAuth is enabled
  static bool get useGoogleMockFallback => false;

  // Checks if the Apple configuration is still using the default template values.
  static bool get useAppleMockFallback => 
      appleServiceId == 'YOUR_APPLE_SERVICE_ID';
}

