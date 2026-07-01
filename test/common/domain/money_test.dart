import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/money.dart';

void main() {
  group('Money', () {
    test('reais -> centavos (arredonda)', () {
      expect(Money.reais(100).centavos, 10000);
      expect(Money.reais(12.34).centavos, 1234);
      expect(Money.reais(0.1).centavos, 10);
    });

    test('reais getter', () {
      expect(const Money(centavos: 12550).reais, 125.5);
    });

    test('soma e subtração operam em centavos', () {
      expect(
        const Money(centavos: 10000) + const Money(centavos: 2550),
        const Money(centavos: 12550),
      );
      expect(
        const Money(centavos: 10000) - const Money(centavos: 2550),
        const Money(centavos: 7450),
      );
    });

    test('multiplicação por fator arredonda', () {
      expect(const Money(centavos: 1000) * 3, const Money(centavos: 3000));
      expect(const Money(centavos: 333) * 1.1, const Money(centavos: 366));
    });

    test('round-trip JSON', () {
      const m = Money(centavos: 123456);
      expect(Money.fromJson(m.toJson()), m);
    });

    test('zero', () {
      expect(Money.zero.centavos, 0);
      expect(Money.zero.isPositivo, isFalse);
      expect(const Money(centavos: 1).isPositivo, isTrue);
    });
  });
}
