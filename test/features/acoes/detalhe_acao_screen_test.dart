import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/cache/cache_snapshot.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/features/acoes/application/cotacao_providers.dart';
import 'package:investa_br/src/features/acoes/domain/cotacao.dart';
import 'package:investa_br/src/features/acoes/domain/fundamentos_acao.dart';
import 'package:investa_br/src/features/acoes/presentation/detalhe_acao_screen.dart';

void main() {
  testWidgets('Detalhe mostra cotação, fundamentos e sinais próprios',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snap = CacheSnapshot<Cotacao>(
      dados: Cotacao(
        ticker: 'PETR4',
        preco: Money.reais(38.54),
        variacaoDiaPct: Percentual.percentual(1.33),
        atualizadoEm: DateTime.utc(2026, 6, 18, 12),
        nomeEmpresa: 'Petrobras PN',
        fundamentos: const FundamentosAcao(precoLucro: 4.62),
      ),
      dataUltimaAtualizacao: '2026-06-18',
      fetchedAt: DateTime.utc(2026, 6, 18, 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cotacaoProvider('PETR4').overrideWith((ref) => snap),
        ],
        child: const MaterialApp(home: DetalheAcaoScreen(ticker: 'PETR4')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Petrobras PN'), findsOneWidget);
    expect(find.text('P/L'), findsOneWidget);
    expect(find.textContaining('Sinais próprios'), findsOneWidget);
    expect(
      find.textContaining('Sem dados de analistas'),
      findsOneWidget,
    );
  });
}
