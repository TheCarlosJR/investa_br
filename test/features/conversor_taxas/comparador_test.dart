import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/indexador.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/features/conversor_taxas/domain/motor/comparador.dart';
import 'package:investa_br/src/features/indicadores/domain/indicadores.dart';

void main() {
  // Índices do dia (decimais anuais) usados nos casos.
  const indicadores = Indicadores(
    cdi: 0.144,
    selic: 0.144,
    ipca: 0.0472,
    igpm: 0.04,
  );

  final opcoes = [
    OpcaoComparacao(
      rotulo: 'A',
      tipo: Posfixado(
        indexador: Indexador.cdi,
        percentualDoIndice: Percentual.percentual(110),
      ),
      isento: false,
    ),
    OpcaoComparacao(
      rotulo: 'B',
      tipo: IndexadoMais(
        indexador: Indexador.ipca,
        taxaReal: Percentual.percentual(6),
      ),
      isento: false,
    ),
    OpcaoComparacao(
      rotulo: 'C',
      tipo: Prefixado(taxaAnual: Percentual.percentual(13.5)),
      isento: false,
    ),
    OpcaoComparacao(
      rotulo: 'D',
      tipo: Posfixado(
        indexador: Indexador.cdi,
        percentualDoIndice: Percentual.percentual(95),
      ),
      isento: true,
    ),
  ];

  group('compararOpcoes (110% CDI x IPCA+6% x 13,5% pré x LCI 95% CDI isenta)',
      () {
    final r = compararOpcoes(
      indicadores: indicadores,
      valor: 10000,
      prazoDias: 720,
      opcoes: opcoes,
    );

    test('retorna uma linha por opção', () {
      expect(r.length, 4);
    });

    test('ordenado por rentabilidade líquida (desc)', () {
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].liquidoAnual, greaterThanOrEqualTo(r[i].liquidoAnual));
      }
    });

    test('a LCI isenta (95% CDI) vence o 110% CDI tributável', () {
      final a = r.firstWhere((e) => e.rotulo == 'A');
      final d = r.firstWhere((e) => e.rotulo == 'D');
      expect(d.liquidoAnual, greaterThan(a.liquidoAnual));
      expect(r.first.rotulo, 'D'); // melhor do ranking
    });

    test('gross-up só para isentos e maior que o líquido', () {
      final d = r.firstWhere((e) => e.rotulo == 'D');
      expect(d.grossUp, isNotNull);
      expect(d.grossUp, greaterThan(d.liquidoAnual));
      expect(r.firstWhere((e) => e.rotulo == 'A').grossUp, isNull);
    });
  });

  test('diasUteisAproximados converte ~365 corridos em ~252 úteis', () {
    expect(diasUteisAproximados(365), 252);
    expect(diasUteisAproximados(730), 504);
  });
}
