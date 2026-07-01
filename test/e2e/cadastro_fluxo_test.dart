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
  }) async => Success(
        CacheSnapshot<List<Indicador>>(
          dados: [
            Indicador(
              tipo: TipoIndicador.cdiDiario,
              valor: 0.0534,
              data: DateTime.utc(2026, 6, 16),
            ),
          ],
          dataUltimaAtualizacao: '2026-06-16',
          fetchedAt: DateTime.utc(2026, 6, 16, 8, 55),
        ),
      );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('cadastrar renda fixa reflete na carteira e no patrimônio',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await newDatabaseFactoryMemory().openDatabase('e2e_cad.db');
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

    // Vai para a Carteira (vazia) e abre o cadastro pelo FAB.
    await tester.tap(find.byIcon(Icons.pie_chart_outline));
    await tester.pumpAndSettle();
    expect(find.text('Carteira vazia'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Novo investimento'), findsOneWidget);

    // Preenche taxa e valor (tipo padrão = Pós-CDI, classe = CDB).
    await tester.enterText(find.widgetWithText(TextFormField, 'Taxa'), '110');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor inicial'),
      '10000',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // De volta na carteira, a posição aparece (apelido padrão = classe).
    expect(find.text('CDB'), findsOneWidget);

    // Na Home, o patrimônio reflete o aporte.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('10.000,00'), findsWidgets);
  });
}
