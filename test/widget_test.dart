import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:investa_br/src/app.dart';
import 'package:investa_br/src/common/cache/cache_snapshot.dart';
import 'package:investa_br/src/common/providers/core_providers.dart';
import 'package:investa_br/src/common/result/result.dart';
import 'package:investa_br/src/features/indicadores/application/indicadores_providers.dart';
import 'package:investa_br/src/features/indicadores/domain/indicador.dart';
import 'package:investa_br/src/features/indicadores/domain/repositories/indicadores_repository.dart';
import 'package:sembast/sembast_memory.dart';

/// Repositório falso (sem rede): devolve um snapshot fixo de indicadores.
class _FakeIndicadoresRepository implements IndicadoresRepository {
  @override
  Future<Result<CacheSnapshot<List<Indicador>>>> obterIndicadores({
    bool forcarRefresh = false,
  }) async {
    final data = DateTime.utc(2026, 6, 16);
    return Success(
      CacheSnapshot<List<Indicador>>(
        dados: [
          Indicador(tipo: TipoIndicador.selicMeta, valor: 14.50, data: data),
          Indicador(tipo: TipoIndicador.cdiDiario, valor: 0.0534, data: data),
          Indicador(tipo: TipoIndicador.ipcaMensal, valor: 0.58, data: data),
          Indicador(tipo: TipoIndicador.igpmMensal, valor: 0.40, data: data),
        ],
        dataUltimaAtualizacao: '2026-06-16',
        fetchedAt: DateTime.utc(2026, 6, 16, 8, 55),
      ),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Dashboard renderiza título, patrimônio e cards de indicadores',
      (tester) async {
    final db = await newDatabaseFactoryMemory().openDatabase('widget.db');
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          indicadoresRepositoryProvider
              .overrideWithValue(_FakeIndicadoresRepository()),
        ],
        child: const InvestaBrApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Investa BR'), findsOneWidget);
    expect(find.text('Patrimônio total'), findsOneWidget);
    expect(find.text('SELIC (meta)'), findsOneWidget);
    expect(find.text('CDI (dia)'), findsOneWidget);
    // Carteira vazia → estado vazio na distribuição.
    expect(find.text('Carteira vazia'), findsOneWidget);
  });
}
