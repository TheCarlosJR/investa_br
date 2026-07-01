import 'package:flutter/material.dart';
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

class _FakeIndicadores implements IndicadoresRepository {
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
        ],
        dataUltimaAtualizacao: '2026-06-16',
        fetchedAt: DateTime.utc(2026, 6, 16, 8, 55),
      ),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('app navega pelas 5 abas do shell', (tester) async {
    // Largura < 600 → NavigationBar (rodapé) com ícones por destino.
    tester.view.physicalSize = const Size(440, 920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await newDatabaseFactoryMemory().openDatabase('e2e_nav.db');
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          indicadoresRepositoryProvider.overrideWithValue(_FakeIndicadores()),
        ],
        child: const InvestaBrApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Início (Dashboard).
    expect(find.text('Patrimônio total'), findsOneWidget);
    expect(find.text('SELIC (meta)'), findsOneWidget);

    // Carteira.
    await tester.tap(find.byIcon(Icons.pie_chart_outline));
    await tester.pumpAndSettle();
    expect(find.text('Carteira vazia'), findsOneWidget);

    // Conversor.
    await tester.tap(find.byIcon(Icons.swap_horiz_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Conversor'), findsOneWidget);

    // Ações.
    await tester.tap(find.byIcon(Icons.search_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Buscar ações da B3'), findsOneWidget);

    // Ajustes.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Aparência'), findsOneWidget);
  });
}
