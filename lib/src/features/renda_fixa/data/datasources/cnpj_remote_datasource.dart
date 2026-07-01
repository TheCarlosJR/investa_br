import 'package:dio/dio.dart';

import '../../../../common/result/failure.dart';
import '../../../../common/result/result.dart';
import '../../domain/emissor.dart';

/// Consulta CNPJ com **fallback encadeado**: BrasilAPI → OpenCNPJ → ReceitaWS.
/// Só propaga `Err` se TODAS falharem. CNPJ é normalizado (só dígitos) antes da
/// chamada. Cada Dio já vem com sua base URL.
class CnpjRemoteDatasource {
  CnpjRemoteDatasource({
    required Dio brasilApi,
    required Dio openCnpj,
    required Dio receitaWs,
  })  : _brasilApi = brasilApi,
        _openCnpj = openCnpj,
        _receitaWs = receitaWs;

  final Dio _brasilApi;
  final Dio _openCnpj;
  final Dio _receitaWs;

  Future<Result<Emissor>> consultar(String cnpjRaw) async {
    final cnpj = cnpjRaw.replaceAll(RegExp(r'\D'), '');
    if (cnpj.length != 14) {
      return const FailureResult(NotFoundFailure('CNPJ inválido'));
    }
    for (final fonte in [_viaBrasilApi, _viaOpenCnpj, _viaReceitaWs]) {
      try {
        final emissor = await fonte(cnpj);
        if (emissor != null) return Success(emissor);
      } on DioException catch (_) {
        // tenta a próxima fonte
      } on FormatException catch (_) {
        // tenta a próxima fonte
      }
    }
    return const FailureResult(
      NetworkFailure('Nenhuma fonte de CNPJ respondeu'),
    );
  }

  Future<Emissor?> _viaBrasilApi(String cnpj) async {
    final r = await _brasilApi.get<dynamic>('/cnpj/v1/$cnpj');
    final d = r.data;
    if (d is! Map) return null;
    final razao = d['razao_social'] as String?;
    if (razao == null) return null;
    return Emissor(
      cnpj: cnpj,
      razaoSocial: razao,
      nomeFantasia: d['nome_fantasia'] as String?,
    );
  }

  Future<Emissor?> _viaOpenCnpj(String cnpj) async {
    final r = await _openCnpj.get<dynamic>('/$cnpj');
    final d = r.data;
    if (d is! Map) return null;
    final razao = d['razao_social'] as String?;
    if (razao == null) return null;
    return Emissor(
      cnpj: cnpj,
      razaoSocial: razao,
      nomeFantasia: d['nome_fantasia'] as String?,
    );
  }

  Future<Emissor?> _viaReceitaWs(String cnpj) async {
    final r = await _receitaWs.get<dynamic>('/cnpj/$cnpj');
    final d = r.data;
    if (d is! Map) return null;
    final nome = d['nome'] as String?;
    if (nome == null) return null;
    return Emissor(
      cnpj: cnpj,
      razaoSocial: nome,
      nomeFantasia: d['fantasia'] as String?,
    );
  }
}
