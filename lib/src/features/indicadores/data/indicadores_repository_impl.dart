import 'package:dio/dio.dart';

import '../../../common/cache/cache_snapshot.dart';
import '../../../common/cache/daily_cache_service.dart';
import '../../../common/network/dio_failure.dart';
import '../../../common/result/failure.dart';
import '../../../common/result/result.dart';
import '../domain/indicador.dart';
import '../domain/repositories/indicadores_repository.dart';
import 'datasources/sgs_remote_datasource.dart';
import 'mappers/serie_sgs_mapper.dart';

class IndicadoresRepositoryImpl implements IndicadoresRepository {
  IndicadoresRepositoryImpl(this._remote, this._cache);

  final SgsRemoteDatasource _remote;
  final DailyCacheService _cache;

  static const String _key = 'indicadores_dia';

  @override
  Future<Result<CacheSnapshot<List<Indicador>>>> obterIndicadores({
    bool forcarRefresh = false,
  }) async {
    // 1) Servir do cache se válido e não for refresh manual.
    final emCache = await _cache.lerSeDeHoje<List<Indicador>>(_key, _fromCache);
    if (!forcarRefresh && emCache != null) {
      return Success(emCache);
    }

    // 2) Buscar remoto.
    try {
      final codigos = TipoIndicador.values.map((t) => t.serieSgs).toList();
      final bruto = await _remote.batchUltimos(codigos);

      final indicadores = <Indicador>[];
      for (final entry in bruto.entries) {
        final tipo = TipoIndicador.fromSerie(entry.key);
        if (tipo == null || entry.value.isEmpty) continue;
        final ponto = entry.value.first;
        indicadores.add(
          Indicador(
            tipo: tipo,
            valor: parseValorSgs(ponto.valor),
            data: parseDataSgs(ponto.data),
            dataFim:
                ponto.dataFim == null ? null : parseDataSgs(ponto.dataFim!),
          ),
        );
      }

      final snap = await _cache.gravar<List<Indicador>>(
        _key,
        indicadores,
        toJson: (l) => l.map((i) => i.toJson()).toList(),
      );
      return Success(snap);
    } on DioException catch (e) {
      // 3) Fallback offline: cache antigo (mesmo vencido) marcado stale.
      final stale = await _cache.lerQualquer<List<Indicador>>(_key, _fromCache);
      if (stale != null) {
        return Success(stale.copyWith(stale: true));
      }
      return FailureResult(mapDioError(e));
    } on FormatException catch (e) {
      return FailureResult(ParseFailure(e.message));
    }
  }

  List<Indicador> _fromCache(Object? json) => (json! as List)
      .map((e) => Indicador.fromJson(e as Map<String, Object?>))
      .toList();
}
