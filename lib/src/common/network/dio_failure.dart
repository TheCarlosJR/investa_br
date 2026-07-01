import 'package:dio/dio.dart';

import '../result/failure.dart';

/// Mapeia uma [DioException] para um [Failure] tipado, na fronteira do
/// repositório. Único ponto de tradução de erros HTTP/rede do app.
Failure mapDioError(DioException e) {
  final status = e.response?.statusCode;
  if (status == 401 || status == 403) {
    return const AuthFailure();
  }
  if (status == 429) {
    final retry = e.response?.headers.value('retry-after');
    return RateLimitFailure(
      'Limite de requisições atingido',
      retryAfter: retry == null ? null : Duration(seconds: int.tryParse(retry) ?? 60),
    );
  }
  if (status == 404) {
    return const NotFoundFailure('Recurso não encontrado');
  }
  if (status != null && status >= 500) {
    return UnknownFailure('Servidor indisponível ($status)');
  }
  return switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      const NetworkFailure('Sem conexão'),
    _ => UnknownFailure(e.message ?? 'Erro desconhecido'),
  };
}
