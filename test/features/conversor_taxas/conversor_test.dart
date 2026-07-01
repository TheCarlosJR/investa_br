import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/indexador.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/features/conversor_taxas/domain/motor/conversor.dart';
import 'package:investa_br/src/features/indicadores/domain/indicadores.dart';

void main() {
  const idx = Indicadores(cdi: 0.10, selic: 0.105, ipca: 0.04, igpm: 0.05);

  group('iBrutaAnualDe', () {
    test('prefixado retorna a própria taxa', () {
      expect(
        iBrutaAnualDe(Prefixado(taxaAnual: Percentual.percentual(13)), idx),
        closeTo(0.13, 1e-12),
      );
    });

    test('110% do CDI compõe sobre o índice', () {
      expect(
        iBrutaAnualDe(
          const Posfixado(
            indexador: Indexador.cdi,
            percentualDoIndice: Percentual(fracao: 1.10),
          ),
          idx,
        ),
        closeTo(0.110535, 1e-5),
      );
    });

    test('IPCA+6% multiplica os fatores', () {
      expect(
        iBrutaAnualDe(
          IndexadoMais(
            indexador: Indexador.ipca,
            taxaReal: Percentual.percentual(6),
          ),
          idx,
        ),
        closeTo(1.04 * 1.06 - 1, 1e-12),
      );
    });
  });

  group('taxaLiquidaAnualEfetiva', () {
    test('tributável 1 ano desconta IR de 17,5%', () {
      // vi=1000, 10% a.a., du=252, dc=365 (>360 => 17,5%). vfLiq=1082,5.
      expect(
        taxaLiquidaAnualEfetiva(
          vi: 1000,
          iBrutaAnual: 0.10,
          prazoDias: 365,
          diasUteis: 252,
          isento: true,
        ),
        closeTo(0.10, 1e-9),
      );
      expect(
        taxaLiquidaAnualEfetiva(
          vi: 1000,
          iBrutaAnual: 0.10,
          prazoDias: 365,
          diasUteis: 252,
          isento: false,
        ),
        closeTo(0.0825, 1e-9),
      );
    });

    test('du=0 retorna 0 (sem divisão por zero)', () {
      expect(
        taxaLiquidaAnualEfetiva(
          vi: 1000,
          iBrutaAnual: 0.10,
          prazoDias: 0,
          diasUteis: 0,
          isento: false,
        ),
        0,
      );
    });
  });

  test('taxaBrutaEquivalenteDeIsento (gross-up)', () {
    // 8,25% líquido com IR de 17,5% -> 10% bruto.
    expect(taxaBrutaEquivalenteDeIsento(0.0825, 365), closeTo(0.10, 1e-9));
  });
}
