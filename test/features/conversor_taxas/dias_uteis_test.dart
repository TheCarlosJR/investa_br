import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/conversor_taxas/domain/motor/dias_uteis.dart';

void main() {
  group('diasUteisEntre', () {
    // 2024-01-01 é segunda-feira.
    final segunda = DateTime(2024);
    final proximaSegunda = DateTime(2024, 1, 8);

    test('uma semana = 5 dias úteis (sem feriados)', () {
      expect(diasUteisEntre(segunda, proximaSegunda, {}), 5);
    });

    test('desconta feriado nacional', () {
      expect(
        diasUteisEntre(segunda, proximaSegunda, {DateTime(2024)}),
        4,
      );
    });

    test('intervalo vazio ou invertido = 0', () {
      expect(diasUteisEntre(segunda, segunda, {}), 0);
      expect(diasUteisEntre(proximaSegunda, segunda, {}), 0);
    });

    test('normaliza hora dos feriados', () {
      expect(
        diasUteisEntre(segunda, proximaSegunda, {DateTime(2024, 1, 1, 13, 30)}),
        4,
      );
    });
  });

  group('diasCorridosEntre', () {
    test('conta dias corridos', () {
      expect(diasCorridosEntre(DateTime(2024), DateTime(2024, 1, 8)), 7);
      expect(diasCorridosEntre(DateTime(2025), DateTime(2026)), 365);
    });
  });
}
