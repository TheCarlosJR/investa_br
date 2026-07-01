import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/cache/cache_snapshot.dart';
import 'package:investa_br/src/common/cache/daily_cache_service.dart';
import 'package:investa_br/src/common/result/failure.dart';
import 'package:investa_br/src/common/result/result.dart';
import 'package:investa_br/src/features/indicadores/data/datasources/sgs_remote_datasource.dart';
import 'package:investa_br/src/features/indicadores/data/dto/serie_sgs_ponto_dto.dart';
import 'package:investa_br/src/features/indicadores/data/indicadores_repository_impl.dart';
import 'package:investa_br/src/features/indicadores/domain/indicador.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sembast/sembast_memory.dart';

class _MockSgs extends Mock implements SgsRemoteDatasource {}

Map<int, List<SerieSgsPontoDto>> _good() => {
      432: [const SerieSgsPontoDto(data: '17/06/2026', valor: '14.50')],
      12: [const SerieSgsPontoDto(data: '16/06/2026', valor: '0.053400')],
      195: [
        const SerieSgsPontoDto(
          data: '16/06/2026',
          dataFim: '16/07/2026',
          valor: '0.6729',
        ),
      ],
    };

DioException _dio(DioExceptionType type, {int? status}) => DioException(
      requestOptions: RequestOptions(),
      type: type,
      response: status == null
          ? null
          : Response<dynamic>(
              requestOptions: RequestOptions(),
              statusCode: status,
            ),
    );

void main() {
  setUpAll(() => registerFallbackValue(<int>[]));

  late Database db;
  late _MockSgs sgs;
  late IndicadoresRepositoryImpl repo;

  final now = DateTime.utc(2026, 6, 17, 12);

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('c.db');
    sgs = _MockSgs();
    final cache = DailyCacheService(
      db,
      stringMapStoreFactory.store('cache_indicadores'),
      now: () => now,
    );
    repo = IndicadoresRepositoryImpl(sgs, cache);
  });

  CacheSnapshot<List<Indicador>> ok(Result<CacheSnapshot<List<Indicador>>> r) =>
      (r as Success<CacheSnapshot<List<Indicador>>>).value;

  test('cache miss: busca remoto, persiste e retorna Success não-stale', () async {
    when(() => sgs.batchUltimos(any())).thenAnswer((_) async => _good());

    final res = await repo.obterIndicadores();
    final snap = ok(res);
    expect(snap.stale, isFalse);
    expect(
      snap.dados.any((i) => i.tipo == TipoIndicador.selicMeta && i.valor == 14.5),
      isTrue,
    );
    verify(() => sgs.batchUltimos(any())).called(1);
  });

  test('cache hit: segunda chamada não toca o remoto', () async {
    when(() => sgs.batchUltimos(any())).thenAnswer((_) async => _good());
    await repo.obterIndicadores(); // popula o cache
    clearInteractions(sgs);

    final res = await repo.obterIndicadores();
    expect(ok(res).dados, isNotEmpty);
    verifyNever(() => sgs.batchUltimos(any()));
  });

  test('forcarRefresh ignora o cache e rebusca', () async {
    when(() => sgs.batchUltimos(any())).thenAnswer((_) async => _good());
    await repo.obterIndicadores();
    clearInteractions(sgs);

    await repo.obterIndicadores(forcarRefresh: true);
    verify(() => sgs.batchUltimos(any())).called(1);
  });

  test('erro de rede COM cache existente: Success marcado stale', () async {
    when(() => sgs.batchUltimos(any())).thenAnswer((_) async => _good());
    await repo.obterIndicadores(); // popula o cache

    when(() => sgs.batchUltimos(any()))
        .thenThrow(_dio(DioExceptionType.connectionError));
    final res = await repo.obterIndicadores(forcarRefresh: true);
    expect(ok(res).stale, isTrue);
  });

  test('erro de rede SEM cache: FailureResult(NetworkFailure)', () async {
    when(() => sgs.batchUltimos(any()))
        .thenThrow(_dio(DioExceptionType.connectionError));
    final res = await repo.obterIndicadores();
    expect(res, isA<FailureResult<CacheSnapshot<List<Indicador>>>>());
    expect(
      (res as FailureResult<CacheSnapshot<List<Indicador>>>).failure,
      isA<NetworkFailure>(),
    );
  });

  test('HTTP 429 SEM cache: FailureResult(RateLimitFailure)', () async {
    when(() => sgs.batchUltimos(any()))
        .thenThrow(_dio(DioExceptionType.badResponse, status: 429));
    final res = await repo.obterIndicadores();
    expect(
      (res as FailureResult<CacheSnapshot<List<Indicador>>>).failure,
      isA<RateLimitFailure>(),
    );
  });
}
