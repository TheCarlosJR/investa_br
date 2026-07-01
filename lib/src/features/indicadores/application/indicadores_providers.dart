import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/cache/cache_snapshot.dart';
import '../../../common/cache/daily_cache_service.dart';
import '../../../common/network/api_endpoints.dart';
import '../../../common/network/dio_factory.dart';
import '../../../common/persistence/local_db.dart';
import '../../../common/providers/core_providers.dart';
import '../../../common/result/failure.dart';
import '../../../common/result/result.dart';
import '../data/datasources/sgs_remote_datasource.dart';
import '../data/indicadores_repository_impl.dart';
import '../domain/indicador.dart';
import '../domain/indicadores.dart';
import '../domain/indicadores_anualizados.dart';
import '../domain/repositories/indicadores_repository.dart';

/// `Dio` dedicado ao BCB SGS (User-Agent obrigatório).
final sgsDioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.criar(baseUrl: ApiEndpoints.sgsBase, comUserAgent: true);
  ref.onDispose(dio.close);
  return dio;
});

final sgsRemoteDatasourceProvider = Provider<SgsRemoteDatasource>(
  (ref) => SgsRemoteDatasource(ref.watch(sgsDioProvider)),
);

/// Cache diário do snapshot de indicadores (store `cache_indicadores`).
final cacheIndicadoresProvider = Provider<DailyCacheService>((ref) {
  return DailyCacheService(
    ref.watch(databaseProvider),
    LocalDb.cacheIndicadores,
    now: ref.watch(clockProvider),
  );
});

final indicadoresRepositoryProvider = Provider<IndicadoresRepository>(
  (ref) => IndicadoresRepositoryImpl(
    ref.watch(sgsRemoteDatasourceProvider),
    ref.watch(cacheIndicadoresProvider),
  ),
);

/// Snapshot de indicadores do dia (cache-first + fallback offline `stale`).
/// A UI consome o `AsyncValue`; em erro de rede sem cache algum, vira
/// `AsyncError` carregando o [Failure].
class IndicadoresNotifier
    extends AsyncNotifier<CacheSnapshot<List<Indicador>>> {
  @override
  Future<CacheSnapshot<List<Indicador>>> build() => _carregar();

  Future<CacheSnapshot<List<Indicador>>> _carregar({
    bool forcarRefresh = false,
  }) async {
    final repo = ref.read(indicadoresRepositoryProvider);
    final res = await repo.obterIndicadores(forcarRefresh: forcarRefresh);
    return switch (res) {
      Success(:final value) => value,
      // Propaga a Failure como erro do AsyncValue (a UI faz pattern match).
      FailureResult(:final failure) => throw failure,
    };
  }

  /// Refresh manual (botão 🔄 / pull-to-refresh): ignora o cache do dia,
  /// mantendo o dado anterior visível enquanto recarrega.
  Future<void> atualizar() async {
    state = const AsyncValue<CacheSnapshot<List<Indicador>>>.loading()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(() => _carregar(forcarRefresh: true));
  }
}

final indicadoresProvider = AsyncNotifierProvider<IndicadoresNotifier,
    CacheSnapshot<List<Indicador>>>(IndicadoresNotifier.new);

/// Indicadores anualizados (entrada do motor). `null` enquanto não há snapshot
/// disponível — o consumidor degrada para os dados contratados.
final indicadoresMotorProvider = Provider<Indicadores?>((ref) {
  final snap = ref.watch(indicadoresProvider).valueOrNull;
  if (snap == null) return null;
  return anualizarIndicadores(snap.dados);
});
