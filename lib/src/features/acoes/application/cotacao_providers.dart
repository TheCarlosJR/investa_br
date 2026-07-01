import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/cache/cache_snapshot.dart';
import '../../../common/network/api_endpoints.dart';
import '../../../common/network/dio_factory.dart';
import '../../../common/providers/core_providers.dart';
import '../../../common/result/result.dart';
import '../../configuracoes/application/config_providers.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../data/cotacao_repository.dart';
import '../data/datasources/brapi_remote_datasource.dart';
import '../domain/cotacao.dart';

/// `Dio` da brapi, com o token corrente injetado (interceptor). Recriado quando
/// o token muda.
final brapiDioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.criar(
    baseUrl: ApiEndpoints.brapiV1,
    token: ref.watch(brapiTokenProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

final brapiDatasourceProvider = Provider<BrapiRemoteDatasource>(
  (ref) => BrapiRemoteDatasource(ref.watch(brapiDioProvider)),
);

final cotacaoRepositoryProvider = Provider<CotacaoRepository>(
  (ref) => CotacaoRepository(
    ref.watch(brapiDatasourceProvider),
    // Reaproveita o store de cache (chaves `cotacao_<ticker>`; fora do export).
    ref.watch(cacheIndicadoresProvider),
    ref.watch(clockProvider),
  ),
);

/// Cotação de um ticker (cache-first + fallback offline `stale`). Erros viram
/// `AsyncError` carregando o `Failure` (a UI faz pattern match).
final cotacaoProvider =
    FutureProvider.family<CacheSnapshot<Cotacao>, String>((ref, ticker) async {
  final res = await ref.watch(cotacaoRepositoryProvider).obterCotacao(ticker);
  return switch (res) {
    Success(:final value) => value,
    FailureResult(:final failure) => throw failure,
  };
});

/// Busca de tickers por termo (≥ 2 caracteres).
final buscaAcoesProvider =
    FutureProvider.family<List<String>, String>((ref, termo) async {
  final t = termo.trim();
  if (t.length < 2) return const [];
  final res = await ref.watch(cotacaoRepositoryProvider).buscar(t);
  return switch (res) {
    Success(:final value) => value,
    FailureResult(:final failure) => throw failure,
  };
});
