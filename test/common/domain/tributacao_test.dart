import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/enums/tributacao.dart';

void main() {
  group('aliquotaIrRegressivo', () {
    test('faixas regressivas por dias corridos', () {
      expect(aliquotaIrRegressivo(180, isento: false), 0.225);
      expect(aliquotaIrRegressivo(181, isento: false), 0.20);
      expect(aliquotaIrRegressivo(360, isento: false), 0.20);
      expect(aliquotaIrRegressivo(361, isento: false), 0.175);
      expect(aliquotaIrRegressivo(720, isento: false), 0.175);
      expect(aliquotaIrRegressivo(721, isento: false), 0.15);
    });

    test('isento sempre zero', () {
      expect(aliquotaIrRegressivo(30, isento: true), 0);
      expect(aliquotaIrRegressivo(1000, isento: true), 0);
    });
  });

  group('aliquotaIofRegressivo', () {
    test('tabela do Decreto 6.306/2007', () {
      expect(aliquotaIofRegressivo(1), 0.96);
      expect(aliquotaIofRegressivo(10), 0.66);
      expect(aliquotaIofRegressivo(15), 0.50);
      expect(aliquotaIofRegressivo(20), 0.33);
      expect(aliquotaIofRegressivo(29), 0.03);
      expect(aliquotaIofRegressivo(30), 0);
      expect(aliquotaIofRegressivo(60), 0);
    });
  });

  group('RegraTributaria vigente 2026', () {
    final regra = regraTributariaVigente2026;

    test('isenção por classe', () {
      expect(regra.isento(ClasseAtivo.lci), isTrue);
      expect(regra.isento(ClasseAtivo.lca), isTrue);
      expect(regra.isento(ClasseAtivo.poupanca), isTrue);
      expect(regra.isento(ClasseAtivo.debentureIncentivada), isTrue);
      expect(regra.isento(ClasseAtivo.cdb), isFalse);
      expect(regra.isento(ClasseAtivo.tesouroSelic), isFalse);
    });

    test('aliquotaIr deriva da classe', () {
      expect(regra.aliquotaIr(ClasseAtivo.cdb, 200), 0.20);
      expect(regra.aliquotaIr(ClasseAtivo.lci, 200), 0);
    });

    test('tributacaoDe', () {
      expect(regra.tributacaoDe(ClasseAtivo.cdb), Tributacao.irRegressivo);
      expect(regra.tributacaoDe(ClasseAtivo.lci), Tributacao.isentoIrPf);
    });
  });
}
