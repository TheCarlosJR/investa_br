import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/indicadores/domain/indicador.dart';
import 'package:investa_br/src/features/indicadores/domain/indicadores_anualizados.dart';

Indicador _ind(TipoIndicador tipo, double valor) =>
    Indicador(tipo: tipo, valor: valor, data: DateTime.utc(2026, 6, 16));

void main() {
  group('anualizarIndicadores', () {
    test('SELIC meta já vem anual (% a.a.) → só divide por 100', () {
      final r = anualizarIndicadores([_ind(TipoIndicador.selicMeta, 14.50)]);
      expect(r.selic, closeTo(0.1450, 1e-9));
    });

    test('CDI diário (% ao dia) → composto em 252 dias úteis', () {
      final r = anualizarIndicadores([_ind(TipoIndicador.cdiDiario, 0.0534)]);
      final esperado = pow(1 + 0.0534 / 100, 252).toDouble() - 1;
      expect(r.cdi, closeTo(esperado, 1e-9));
      // sanity: ~14% a.a.
      expect(r.cdi, closeTo(0.144, 0.01));
    });

    test('IPCA/IGP-M mensais (% mês) → compostos em 12 meses', () {
      final r = anualizarIndicadores([
        _ind(TipoIndicador.ipcaMensal, 0.58),
        _ind(TipoIndicador.igpmMensal, 0.40),
      ]);
      expect(r.ipca, closeTo(pow(1.0058, 12).toDouble() - 1, 1e-9));
      expect(r.igpm, closeTo(pow(1.0040, 12).toDouble() - 1, 1e-9));
    });

    test('indicadores ausentes degradam para zero', () {
      final r = anualizarIndicadores([_ind(TipoIndicador.selicMeta, 14.5)]);
      expect(r.cdi, 0);
      expect(r.ipca, 0);
      expect(r.igpm, 0);
    });

    test('snapshot vazio → tudo zero', () {
      final r = anualizarIndicadores([]);
      expect(r.cdi, 0);
      expect(r.selic, 0);
      expect(r.ipca, 0);
      expect(r.igpm, 0);
    });
  });
}
