import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/utils/parsers.dart';

void main() {
  group('parseNumeroPtBr', () {
    test('vírgula decimal', () {
      expect(parseNumeroPtBr('10000,50'), 10000.50);
      expect(parseNumeroPtBr('13,5'), 13.5);
    });

    test('ponto milhar + vírgula decimal', () {
      expect(parseNumeroPtBr('10.000,50'), 10000.50);
      expect(parseNumeroPtBr('1.234.567,89'), 1234567.89);
    });

    test('só ponto: milhar quando grupo final tem 3 dígitos', () {
      expect(parseNumeroPtBr('1.000'), 1000);
      expect(parseNumeroPtBr('1.000.000'), 1000000);
    });

    test('só ponto: decimal quando 1-2 dígitos finais', () {
      expect(parseNumeroPtBr('10.5'), 10.5);
      expect(parseNumeroPtBr('10.50'), 10.50);
    });

    test(r'prefixo R$ e espaços são ignorados', () {
      expect(parseNumeroPtBr(r'R$ 10.000,00'), 10000.0);
    });

    test('vazio ou inválido → null', () {
      expect(parseNumeroPtBr(''), isNull);
      expect(parseNumeroPtBr('  '), isNull);
      expect(parseNumeroPtBr('abc'), isNull);
    });
  });
}
