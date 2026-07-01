import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/percentual.dart';

void main() {
  group('Percentual', () {
    test('factory percentual converte para fração', () {
      expect(Percentual.percentual(14.5).fracao, closeTo(0.145, 1e-12));
      expect(Percentual.percentual(110).fracao, closeTo(1.10, 1e-12));
    });

    test('aPercentual', () {
      expect(const Percentual(fracao: 0.145).aPercentual, closeTo(14.5, 1e-12));
    });

    test('parseSgs aceita vírgula e ponto', () {
      expect(Percentual.parseSgs('14,50').aPercentual, closeTo(14.5, 1e-12));
      expect(Percentual.parseSgs('0.053400').fracao, closeTo(0.000534, 1e-12));
      expect(Percentual.parseSgs(' 14.50 ').aPercentual, closeTo(14.5, 1e-12));
    });

    test('round-trip JSON', () {
      const p = Percentual(fracao: 0.1234);
      expect(Percentual.fromJson(p.toJson()), p);
    });
  });
}
