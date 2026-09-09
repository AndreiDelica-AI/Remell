import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

const String _tokenStorageKey = 'remell_auth_token';
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

void saveAuthSession(String? token, Map<String, dynamic>? user) {
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
    } else {
      html.window.localStorage[_logoutStorageKey] = 'true';
      html.window.localStorage.remove(_tokenStorageKey);
      html.window.localStorage.remove(_userStorageKey);
    }
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
