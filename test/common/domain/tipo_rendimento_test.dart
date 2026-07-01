import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/indexador.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';

void main() {
  group('TipoRendimento round-trip JSON', () {
    void roundTrip(TipoRendimento t) {
      expect(TipoRendimento.fromJson(t.toJson()), t);
    }

    test('prefixado', () {
      roundTrip(Prefixado(taxaAnual: Percentual.percentual(13)));
    });

    test('posfixado %CDI', () {
      roundTrip(
        const Posfixado(
          indexador: Indexador.cdi,
          percentualDoIndice: Percentual(fracao: 1.10),
        ),
      );
    });

    test('indexadoMais IPCA+', () {
      roundTrip(
        IndexadoMais(
          indexador: Indexador.ipca,
          taxaReal: Percentual.percentual(6),
        ),
      );
    });

    test('percentualPuro ao mês', () {
      roundTrip(
        PercentualPuro(
          taxa: Percentual.percentual(1),
          periodo: PeriodoTaxa.aoMes,
        ),
      );
    });

    test('discriminador estável "tipo"', () {
      final json = const Posfixado(
        indexador: Indexador.cdi,
        percentualDoIndice: Percentual(fracao: 1.10),
      ).toJson();
      expect(json['tipo'], 'posfixado');
      expect(json['indexador'], 'cdi');
    });
  });
}
