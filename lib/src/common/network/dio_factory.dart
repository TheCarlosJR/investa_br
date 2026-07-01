import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Cria um [Dio] por API, com os interceptors apropriados.
abstract final class DioFactory {
  static Dio criar({
    required String baseUrl,
    bool comUserAgent = false,
    String? token,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    if (comUserAgent) dio.interceptors.add(UserAgentInterceptor());
    if (token != null && token.isNotEmpty) {
      dio.interceptors.add(BrapiTokenInterceptor(token));
    }
    if (kDebugMode) dio.interceptors.add(LoggingInterceptor());
    return dio;
  }
}

/// O BCB SGS rejeita clientes sem User-Agent "comum".
class UserAgentInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['User-Agent'] = 'InvestaBR/1.0 (Flutter)';
    handler.next(options);
  }
}

/// Injeta o token da brapi (`Authorization: Bearer <token>`).
class BrapiTokenInterceptor extends Interceptor {
  BrapiTokenInterceptor(this._token);
  final String _token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }
}

/// Log de request/response (apenas em debug).
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log('-> ${options.method} ${options.uri}', name: 'dio');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    developer.log(
      '<- ${response.statusCode} ${response.requestOptions.uri}',
      name: 'dio',
    );
    handler.next(response);
  }
}
