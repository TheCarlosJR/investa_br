import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/common/providers/core_providers.dart';
import 'package:investa_br/src/features/acoes/application/acoes_list_provider.dart';
import 'package:investa_br/src/features/acoes/domain/posicao_acao.dart';
import 'package:investa_br/src/features/indicadores/application/indicadores_providers.dart';
import 'package:investa_br/src/features/renda_fixa/application/renda_fixa_list_provider.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';
import 'package:investa_br/src/features/renda_fixa/presentation/carteira_screen.dart';

final _now = DateTime.utc(2027, 6, 18);

/// Fakes que devolvem listas em memória (sem banco real) — evitam timers
/// pendentes do datasource no widget test.
class _FakeRf extends RendaFixaListNotifier {
  _FakeRf(this.items);
  final List<InvestimentoRendaFixa> items;
  @override
  Future<List<InvestimentoRendaFixa>> build() async => items;
}

class _FakeAcoes extends AcoesListNotifier {
  _FakeAcoes(this.items);
  final List<PosicaoAcao> items;
  @override
  Future<List<PosicaoAcao>> build() async => items;
}

void main() {
  testWidgets('Carteira lista RF e ações com totais', (tester) async {
    final rf = InvestimentoRendaFixa(
      id: 'a',
      classe: ClasseAtivo.cdb,
      apelido: 'CDB Banco X',
      valorInicial: Money.reais(10000),
      taxa: TaxaContratada(
        tipoRendimento: Prefixado(taxaAnual: Percentual.percentual(13)),
      ),
      dataInicio: _now.subtract(const Duration(days: 30)),
      createdAt: _now,
      updatedAt: _now,
    );
    final acao = PosicaoAcao(
      id: 'x',
      ticker: 'PETR4',
      quantidade: 100,
      precoMedio: Money.reais(31.20),
      dataCompra: _now,
      createdAt: _now,
      updatedAt: _now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => _now),
          indicadoresMotorProvider.overrideWithValue(null),
          rendaFixaListProvider.overrideWith(() => _FakeRf([rf])),
          acoesListProvider.overrideWith(() => _FakeAcoes([acao])),
        ],
        child: const MaterialApp(home: CarteiraScreen()),
      ),
    );
    // Drena o microtask do build assíncrono dos notifiers (sem pumpAndSettle,
    // que não assenta enquanto o spinner inicial anima).
    await tester.pump();
    await tester.pump();

    expect(find.text('CDB Banco X'), findsOneWidget);
    expect(find.text('PETR4'), findsOneWidget);
    expect(find.textContaining('Renda Fixa'), findsWidgets);
  });
}
