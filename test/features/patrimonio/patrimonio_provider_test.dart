import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/common/providers/core_providers.dart';
import 'package:investa_br/src/features/acoes/application/acoes_providers.dart';
import 'package:investa_br/src/features/acoes/domain/posicao_acao.dart';
import 'package:investa_br/src/features/indicadores/application/indicadores_providers.dart';
import 'package:investa_br/src/features/indicadores/domain/indicadores.dart';
import 'package:investa_br/src/features/patrimonio/application/patrimonio_providers.dart';
import 'package:investa_br/src/features/patrimonio/domain/patrimonio.dart';
import 'package:investa_br/src/features/renda_fixa/application/renda_fixa_providers.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';
import 'package:sembast/sembast_memory.dart';

final _now = DateTime.utc(2027, 6, 18);

InvestimentoRendaFixa _rf({
  required String id,
  required ClasseAtivo classe,
  required double reais,
  double taxaAnual = 0.13,
  DateTime? inicio,
}) =>
    InvestimentoRendaFixa(
      id: id,
      classe: classe,
      apelido: id,
      valorInicial: Money.reais(reais),
      taxa: TaxaContratada(
        tipoRendimento: Prefixado(taxaAnual: Percentual(fracao: taxaAnual)),
      ),
      dataInicio: inicio ?? _now.subtract(const Duration(days: 400)),
      createdAt: _now,
      updatedAt: _now,
    );

PosicaoAcao _acao({required String id, required int qtd, required double preco}) =>
    PosicaoAcao(
      id: id,
      ticker: 'PETR4',
      quantidade: qtd,
      precoMedio: Money.reais(preco),
      dataCompra: _now,
      createdAt: _now,
      updatedAt: _now,
    );

Future<ProviderContainer> _container(String dbName, {Indicadores? motor}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  final c = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      indicadoresMotorProvider.overrideWithValue(motor),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(db.close);
  return c;
}

FatiaPatrimonio _fatia(Patrimonio p, GrupoAtivo g) =>
    p.fatias.firstWhere((f) => f.grupo == g);

void main() {
  group('patrimonioProvider', () {
    test('carteira vazia → Patrimonio vazio', () async {
      final c = await _container('vazio.db');
      final p = await c.read(patrimonioProvider.future);
      expect(p.estaVazio, isTrue);
      expect(p.totalAtual, Money.zero);
      expect(p.totalInvestido, Money.zero);
      expect(p.rendimentoFracao, 0);
    });

    test('sem indicadores: RF degrada para valor inicial; agrupa por grupo',
        () async {
      final c = await _container('semind.db');
      await c.read(rendaFixaRepositoryProvider).salvar(
            _rf(id: 'cdb1', classe: ClasseAtivo.cdb, reais: 10000),
          );
      await c.read(rendaFixaRepositoryProvider).salvar(
            _rf(id: 'ts1', classe: ClasseAtivo.tesouroSelic, reais: 5000),
          );
      await c.read(posicoesAcoesRepositoryProvider).salvar(
            _acao(id: 'a1', qtd: 10, preco: 30),
          );

      final p = await c.read(patrimonioProvider.future);

      // Investido = 10000 + 5000 + (10 × 30) = 15300.
      expect(p.totalInvestido, Money.reais(15300));
      // Sem motor, RF não é marcada → total atual == investido.
      expect(p.totalAtual, Money.reais(15300));
      expect(p.rendimentoFracao, 0);

      // Três grupos, ordenados do maior para o menor.
      expect(p.fatias.map((f) => f.grupo).toList(), [
        GrupoAtivo.rendaFixa,
        GrupoAtivo.tesouroDireto,
        GrupoAtivo.acoes,
      ]);
      expect(_fatia(p, GrupoAtivo.rendaFixa).valorAtual, Money.reais(10000));
      expect(_fatia(p, GrupoAtivo.tesouroDireto).valorAtual, Money.reais(5000));
      expect(_fatia(p, GrupoAtivo.acoes).valorAtual, Money.reais(300));
      expect(p.fracaoDe(_fatia(p, GrupoAtivo.acoes)), closeTo(300 / 15300, 1e-9));
    });

    test('com indicadores: RF prefixada é marcada na curva (cresce)', () async {
      final c = await _container(
        'comind.db',
        motor: const Indicadores(cdi: 0.14, selic: 0.145, ipca: 0.045, igpm: 0.04),
      );
      await c.read(rendaFixaRepositoryProvider).salvar(
            _rf(id: 'cdb1', classe: ClasseAtivo.cdb, reais: 10000),
          );

      final p = await c.read(patrimonioProvider.future);

      expect(p.totalInvestido, Money.reais(10000));
      // Prefixado 13% a.a. por ~400 dias corridos → valor bruto > investido.
      expect(p.totalAtual.centavos, greaterThan(p.totalInvestido.centavos));
      expect(p.rendimentoFracao, greaterThan(0));
      expect(p.fatias.single.grupo, GrupoAtivo.rendaFixa);
    });
  });
}
