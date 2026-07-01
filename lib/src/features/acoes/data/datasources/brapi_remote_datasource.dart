import 'package:dio/dio.dart';

import '../dto/cotacao_brapi_dto.dart';

/// Acesso à brapi.dev. Lança [DioException] (rede/401/429) ou [FormatException]
/// (corpo inesperado); o repositório converte em `Failure`. O token é injetado
/// pelo interceptor do Dio (ver `DioFactory`).
class BrapiRemoteDatasource {
  BrapiRemoteDatasource(this._dio); // base = https://brapi.dev/api

  final Dio _dio;

  /// Cotação + fundamentos de um ticker (`/quote/{ticker}`).
  Future<CotacaoBrapiDto> cotacao(String ticker) async {
    final r = await _dio.get<dynamic>('/quote/$ticker');
    final data = r.data;
    if (data is! Map || data['results'] is! List) {
      throw const FormatException('Resposta brapi sem "results"');
    }
    final results = data['results'] as List;
    if (results.isEmpty || results.first is! Map) {
      throw const FormatException('brapi: ticker sem resultado');
    }
    return CotacaoBrapiDto.fromJson(
      (results.first as Map).cast<String, Object?>(),
    );
  }

  /// Lista de tickers que combinam com [termo] (`/available?search=`).
  Future<List<String>> buscar(String termo) async {
    final r = await _dio.get<dynamic>(
      '/available',
      queryParameters: {'search': termo},
    );
    final data = r.data;
    if (data is! Map || data['stocks'] is! List) {
      throw const FormatException('Resposta brapi /available inesperada');
    }
    return (data['stocks'] as List).whereType<String>().toList();
  }
}
