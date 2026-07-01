import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/indexador.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_descricao.dart';

void main() {
  group('descreverTaxa', () {
    test('prefixado', () {
      final d = descreverTaxa(
        Prefixado(taxaAnual: Percentual.percentual(13)),
      );
      expect(d, '13,00% a.a.');
    });

    test('pós-CDI', () {
      final d = descreverTaxa(
        Posfixado(
          indexador: Indexador.cdi,
          percentualDoIndice: Percentual.percentual(110),
        ),
      );
      expect(d, '110,00% do CDI');
    });

    test('pós-Selic', () {
      final d = descreverTaxa(
        Posfixado(
          indexador: Indexador.selic,
          percentualDoIndice: Percentual.percentual(100),
        ),
      );
      expect(d, '100,00% da Selic');
    });

    test('IPCA+', () {
      final d = descreverTaxa(
        IndexadoMais(indexador: Indexador.ipca, taxaReal: Percentual.percentual(6)),
      );
      expect(d, 'IPCA + 6,00%');
    });

    test('percentual puro', () {
      final d = descreverTaxa(
        PercentualPuro(taxa: Percentual.percentual(12)),
      );
      expect(d, '12,00% (taxa total)');
    });
  });
}
