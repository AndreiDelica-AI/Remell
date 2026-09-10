import 'dart:convert';
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

const String _tokenStorageKey = 'remell_auth_token';
const String _refreshTokenStorageKey = 'remell_auth_refresh_token';
const String _userStorageKey = 'remell_auth_user';
const String _logoutStorageKey = 'remell_auth_logged_out';

bool _isExplicitlyLoggedOut() {
  if (!kIsWeb) return false;
  try {
    return html.window.localStorage[_logoutStorageKey] == 'true';
  } catch (_) {
    return false;
  }
}

String? _getInitialToken() {
  if (_isExplicitlyLoggedOut()) return null;
  if (!kIsWeb) return null;
  try {
    final token = html.window.localStorage[_tokenStorageKey];
    if (token != null && token.isNotEmpty) return token;
  } catch (_) {}
  return null;
}

Map<String, dynamic>? _getInitialUser() {
  if (_isExplicitlyLoggedOut()) return null;
  if (!kIsWeb) return null;
  try {
    final str = html.window.localStorage[_userStorageKey];
    if (str != null && str.isNotEmpty) {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
        return decoded;
      }
    }
  } catch (_) {}
  return null;
}

void saveAuthSession(
  String? token,
  Map<String, dynamic>? user, {
  String? refreshToken,
}) {
  if (!kIsWeb) return;
  try {
    if (token != null || user != null) {
      html.window.localStorage.remove(_logoutStorageKey);
      if (token != null) {
        html.window.localStorage[_tokenStorageKey] = token;
      }
      if (user != null) {
        html.window.localStorage[_userStorageKey] = jsonEncode(user);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        html.window.localStorage[_refreshTokenStorageKey] = refreshToken;
      }
    } else {
      html.window.localStorage[_logoutStorageKey] = 'true';
      html.window.localStorage.remove(_tokenStorageKey);
      html.window.localStorage.remove(_userStorageKey);
      html.window.localStorage.remove(_refreshTokenStorageKey);
    }
  } catch (_) {}
}

/// Refreshes a remembered web session before Riverpod reads its initial state.
/// A temporary network failure keeps the local session intact for offline use.
Future<void> restoreAuthSession() async {
  if (!kIsWeb || _isExplicitlyLoggedOut()) return;
  try {
    final refreshToken = html.window.localStorage[_refreshTokenStorageKey];
    if (refreshToken == null || refreshToken.isEmpty) return;

    final response = await ApiClient().client.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data?['data'];
    if (data is Map) {
      final accessToken = data['accessToken'];
      final rotatedRefreshToken = data['refreshToken'];
      final user = data['user'];
      if (accessToken is String &&
          rotatedRefreshToken is String &&
          user is Map) {
        saveAuthSession(
          accessToken,
          Map<String, dynamic>.from(user),
          refreshToken: rotatedRefreshToken,
        );
      }
    }
  } catch (error) {
    // Only an invalid/expired refresh token should end the remembered session.
    if (error is DioException && error.response?.statusCode == 401) {
      saveAuthSession(null, null);
    }
  }
}

void clearLocalCachePreservingAuth() {
  if (!kIsWeb) return;
  try {
    final preserved = <String, String>{};
    for (final key in [
      _tokenStorageKey,
      _refreshTokenStorageKey,
      _userStorageKey,
      _logoutStorageKey,
    ]) {
      final value = html.window.localStorage[key];
      if (value != null) preserved[key] = value;
    }
    html.window.localStorage.clear();
    preserved.forEach((key, value) {
      html.window.localStorage[key] = value;
    });
  } catch (_) {}
}

// Provider to hold the current session's JWT auth token
final authTokenProvider = StateProvider<String?>((ref) => _getInitialToken());

// Provider to hold current user info returned by backend
final authUserProvider = StateProvider<Map<String, dynamic>?>((ref) => _getInitialUser());

// Provider to dynamically supply the ApiClient with the current authentication token
final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authTokenProvider);
  return ApiClient(token: token);
});
