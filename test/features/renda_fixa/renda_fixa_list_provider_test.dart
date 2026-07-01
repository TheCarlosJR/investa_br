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
import 'package:investa_br/src/features/patrimonio/application/patrimonio_providers.dart';
import 'package:investa_br/src/features/renda_fixa/application/renda_fixa_list_provider.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';
import 'package:sembast/sembast_memory.dart';

final _now = DateTime.utc(2027, 6, 18);

InvestimentoRendaFixa _rf(String id, double reais) => InvestimentoRendaFixa(
      id: id,
      classe: ClasseAtivo.cdb,
      apelido: id,
      valorInicial: Money.reais(reais),
      taxa: TaxaContratada(
        tipoRendimento: Prefixado(taxaAnual: Percentual.percentual(13)),
      ),
      dataInicio: _now.subtract(const Duration(days: 30)),
      createdAt: _now,
      updatedAt: _now,
    );

PosicaoAcao _acao(String id, int qtd, double preco) => PosicaoAcao(
      id: id,
      ticker: 'PETR4',
      quantidade: qtd,
      precoMedio: Money.reais(preco),
      dataCompra: _now,
      createdAt: _now,
      updatedAt: _now,
    );

Future<ProviderContainer> _container(String dbName) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  final c = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      // Sem motor: RF degrada para valor inicial (asserções determinísticas).
      indicadoresMotorProvider.overrideWithValue(null),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(db.close);
  return c;
}

void main() {
  group('rendaFixaListProvider (CRUD)', () {
    test('upsert adiciona e atualiza; remover apaga', () async {
      final c = await _container('crud.db');
      final notifier = c.read(rendaFixaListProvider.notifier);

      expect(await c.read(rendaFixaListProvider.future), isEmpty);

      await notifier.upsert(_rf('a', 10000));
      var lista = await c.read(rendaFixaListProvider.future);
      expect(lista.length, 1);
      expect(lista.single.valorInicial, Money.reais(10000));

      // upsert com mesmo id atualiza (não duplica).
      await notifier.upsert(_rf('a', 12000));
      lista = await c.read(rendaFixaListProvider.future);
      expect(lista.length, 1);
      expect(lista.single.valorInicial, Money.reais(12000));

      await notifier.remover('a');
      expect(await c.read(rendaFixaListProvider.future), isEmpty);
    });

    test('mutações refletem no patrimonioProvider', () async {
      final c = await _container('integra.db');

      // Patrimônio começa vazio.
      expect((await c.read(patrimonioProvider.future)).estaVazio, isTrue);

      await c.read(rendaFixaListProvider.notifier).upsert(_rf('a', 10000));
      await c.read(acoesListProvider.notifier).upsert(_acao('x', 10, 30));

      final p = await c.read(patrimonioProvider.future);
      expect(p.estaVazio, isFalse);
      // 10000 (RF, motor null → valor inicial) + 300 (ação custo) = 10300.
      expect(p.totalAtual, Money.reais(10300));
      expect(p.totalInvestido, Money.reais(10300));

      // Remover a ação recompõe o patrimônio.
      await c.read(acoesListProvider.notifier).remover('x');
      final p2 = await c.read(patrimonioProvider.future);
      expect(p2.totalAtual, Money.reais(10000));
    });
  });
}
