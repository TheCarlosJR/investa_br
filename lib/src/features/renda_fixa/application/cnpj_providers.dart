import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/network/api_endpoints.dart';
import '../../../common/network/dio_factory.dart';
import '../../../common/result/result.dart';
import '../data/datasources/cnpj_remote_datasource.dart';
import '../domain/emissor.dart';

final cnpjDatasourceProvider = Provider<CnpjRemoteDatasource>((ref) {
  final brasilApi = DioFactory.criar(
    baseUrl: ApiEndpoints.brasilApi,
    comUserAgent: true,
  );
  final openCnpj = DioFactory.criar(
    baseUrl: ApiEndpoints.openCnpj,
    comUserAgent: true,
  );
  final receitaWs = DioFactory.criar(
    baseUrl: ApiEndpoints.receitaWs,
    comUserAgent: true,
  );
  ref.onDispose(() {
    brasilApi.close();
    openCnpj.close();
    receitaWs.close();
  });
  return CnpjRemoteDatasource(
    brasilApi: brasilApi,
    openCnpj: openCnpj,
    receitaWs: receitaWs,
  );
});

/// Consulta de CNPJ (fallback encadeado). Erro vira `AsyncError(Failure)`.
final cnpjProvider = FutureProvider.family<Emissor, String>((ref, cnpj) async {
  final res = await ref.watch(cnpjDatasourceProvider).consultar(cnpj);
  return switch (res) {
    Success(:final value) => value,
    FailureResult(:final failure) => throw failure,
  };
});
