import 'package:dio/dio.dart';

import '../dto/serie_sgs_ponto_dto.dart';

/// Acesso ao BCB SGS. Lança [DioException] (rede) ou [FormatException]
/// (resposta não-JSON, ex.: HTML de erro); o repository converte em `Failure`.
class SgsRemoteDatasource {
  SgsRemoteDatasource(this._dio);

  final Dio _dio; // base = https://api.bcb.gov.br/dados/serie

  /// Últimos [n] pontos de uma série. `/ultimos/{n}` não sofre o limite de
  /// janela de 10 anos.
  Future<List<SerieSgsPontoDto>> ultimos(int codigo, {int n = 1}) async {
    final r = await _dio.get<dynamic>(
      '/bcdata.sgs.$codigo/dados/ultimos/$n',
      queryParameters: const {'formato': 'json'},
    );
    final data = r.data;
    if (data is! List) {
      throw const FormatException('Resposta SGS não é um JSON array');
    }
    return data
        .cast<Map<String, dynamic>>()
        .map(SerieSgsPontoDto.fromJson)
        .toList();
  }

  /// Batch respeitando o limite de cortesia (~5 requisições simultâneas).
  Future<Map<int, List<SerieSgsPontoDto>>> batchUltimos(
    List<int> codigos, {
    int concorrencia = 5,
  }) async {
    final out = <int, List<SerieSgsPontoDto>>{};
    for (var i = 0; i < codigos.length; i += concorrencia) {
      final lote = codigos.skip(i).take(concorrencia);
      final res = await Future.wait(
        lote.map((c) async => MapEntry(c, await ultimos(c))),
      );
      out.addEntries(res);
    }
    return out;
  }
}
