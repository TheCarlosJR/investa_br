import 'package:dio/dio.dart';

import '../../../common/cache/cache_snapshot.dart';
import '../../../common/cache/daily_cache_service.dart';
import '../../../common/network/dio_failure.dart';
import '../../../common/result/failure.dart';
import '../../../common/result/result.dart';
import '../domain/cotacao.dart';
import 'datasources/brapi_remote_datasource.dart';
import 'mappers/cotacao_mapper.dart';

/// Cotações da brapi com cache diário por ticker (sob demanda — não entram no
/// boot). Em falha de rede, faz fallback para o último snapshot `stale`.
class CotacaoRepository {
  CotacaoRepository(this._remote, this._cache, this._clock);

  final BrapiRemoteDatasource _remote;
  final DailyCacheService _cache;
  final DateTime Function() _clock;

  String _key(String ticker) => 'cotacao_${ticker.toUpperCase()}';

  Cotacao _fromCache(Object? json) =>
      Cotacao.fromJson(json! as Map<String, Object?>);

  Future<Result<CacheSnapshot<Cotacao>>> obterCotacao(
    String ticker, {
    bool forcarRefresh = false,
  }) async {
    final key = _key(ticker);
    final emCache = await _cache.lerSeDeHoje<Cotacao>(key, _fromCache);
    if (!forcarRefresh && emCache != null) return Success(emCache);

    try {
      final dto = await _remote.cotacao(ticker.toUpperCase());
      final cotacao = cotacaoFromDto(dto, _clock());
      final snap =
          await _cache.gravar<Cotacao>(key, cotacao, toJson: (c) => c.toJson());
      return Success(snap);
    } on DioException catch (e) {
      final stale = await _cache.lerQualquer<Cotacao>(key, _fromCache);
      if (stale != null) return Success(stale.copyWith(stale: true));
      return FailureResult(mapDioError(e));
    } on FormatException catch (e) {
      return FailureResult(ParseFailure(e.message));
    }
  }

  Future<Result<List<String>>> buscar(String termo) async {
    try {
      return Success(await _remote.buscar(termo));
    } on DioException catch (e) {
      return FailureResult(mapDioError(e));
    } on FormatException catch (e) {
      return FailureResult(ParseFailure(e.message));
    }
  }
}
