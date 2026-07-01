import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/conversor_taxas/domain/motor/juros.dart';

void main() {
  group('motor de juros', () {
    test('vfBase252 com du=252 reproduz a taxa anual', () {
      expect(vfBase252(1000, 0.10, 252), closeTo(1100, 1e-6));
    });

    test('vfBase252 com meio período', () {
      expect(vfBase252(1000, 0.10, 126), closeTo(1000 * sqrt(1.10), 1e-6));
    });

    test('fatorDiario252', () {
      expect(fatorDiario252(0.10), closeTo(pow(1.10, 1 / 252).toDouble(), 1e-12));
    });

    test('vfPercentualCdi 110% do CDI', () {
      // 1000 * (1.10)^1.10
      expect(
        vfPercentualCdi(1000, 0.10, 1.10, 252),
        closeTo(1000 * pow(1.10, 1.10).toDouble(), 1e-6),
      );
    });

    test('vfBase365 com 365 dias reproduz a taxa anual', () {
      expect(vfBase365(1000, 0.10, 365), closeTo(1100, 1e-6));
    });

    test('vfHibrido IPCA(5%)+6%', () {
      expect(vfHibrido(1000, 0.05, 0.06, 252), closeTo(1113, 1e-6));
    });

    test('percentual puro composto x simples', () {
      expect(vfPercentualPuroComposto(1000, 0.01, 12), closeTo(1126.825, 1e-2));
      expect(vfPercentualPuroSimples(1000, 0.01, 12), closeTo(1120, 1e-6));
    });

    test('vfPercentualCdiHistorico == forma fechada quando pct=1.0 (100% CDI)',
        () {
      final cdis = List<double>.filled(252, 0.10);
      // Para 100% do CDI as duas convenções coincidem exatamente.
      expect(
        vfPercentualCdiHistorico(1000, cdis, 1),
        closeTo(vfPercentualCdi(1000, 0.10, 1, 252), 1e-6),
      );
    });

    test('vfPercentualCdiHistorico diverge da forma fechada quando pct != 1', () {
      // Para 110% do CDI o produtório diário ("spread sobre o CDI", convenção
      // B3) difere da aproximação fechada (1+cdi)^(p·du/252) — diferença real,
      // não erro: a forma fechada é apenas aproximação para projeção.
      final cdis = List<double>.filled(252, 0.10);
      final historico = vfPercentualCdiHistorico(1000, cdis, 1.10);
      final fechada = vfPercentualCdi(1000, 0.10, 1.10, 252);
      expect(historico, isNot(closeTo(fechada, 1e-6)));
      expect((historico - fechada).abs(), lessThan(1)); // < R\$ 1 em R\$ 1110
    });
  });
}
