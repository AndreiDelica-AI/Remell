import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  ApiClient({String? baseUrl, String? token}) {
    final resolvedBaseUrl = baseUrl ?? (apiBaseUrl.isNotEmpty 
        ? apiBaseUrl 
        : (kIsWeb && Uri.base.host.isNotEmpty ? 'http://${Uri.base.host}:5000' : 'http://localhost:5000'));
    _dio = Dio(
      BaseOptions(
        baseUrl: resolvedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    // Logging & token refresh interceptors would be added here
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add Request ID header required by backend logs
          options.headers['x-request-id'] = 'flutter-${DateTime.now().millisecondsSinceEpoch}';
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Centrally parse and handle network interruption or offline state
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.message?.contains('SocketException') == true ||
              e.message?.contains('Failed host lookup') == true) {
            debugPrint('[ApiClient] Network connection interrupted or offline.');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;
}


