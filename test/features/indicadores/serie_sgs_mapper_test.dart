import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/indicadores/data/mappers/serie_sgs_mapper.dart';

void main() {
  group('parseValorSgs', () {
    test('aceita ponto e vírgula', () {
      expect(parseValorSgs('14.50'), 14.5);
      expect(parseValorSgs('14,50'), 14.5);
      expect(parseValorSgs(' 0.053400 '), closeTo(0.0534, 1e-12));
    });

    test('valor inválido lança FormatException', () {
      expect(() => parseValorSgs('abc'), throwsFormatException);
    });
  });

  group('parseDataSgs', () {
    test('dd/MM/yyyy', () {
      expect(parseDataSgs('17/06/2026'), DateTime(2026, 6, 17));
    });

    test('formato inválido lança FormatException', () {
      expect(() => parseDataSgs('2026-06-17'), throwsFormatException);
    });
  });
}
