import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/configuracoes/data/import_export/backup_codec.dart';

void main() {
  group('backup_codec', () {
    test('canonicalJson ordena chaves recursivamente', () {
      expect(
        canonicalJson({
          'b': 1,
          'a': {'d': 4, 'c': 3},
        }),
        '{"a":{"c":3,"d":4},"b":1}',
      );
    });

    test('checksum é estável independente da ordem das chaves', () {
      final d1 = <String, Object?>{
        'a': 1,
        'b': [
          1,
          2,
          {'x': 1, 'y': 2},
        ],
      };
      final d2 = <String, Object?>{
        'b': [
          1,
          2,
          {'y': 2, 'x': 1},
        ],
        'a': 1,
      };
      expect(sha256Of(d1), sha256Of(d2));
    });

    test('verifyChecksum detecta adulteração', () {
      final data = <String, Object?>{'k': 'v'};
      final checksum = buildChecksum(data);
      expect(verifyChecksum(data, checksum), isTrue);
      expect(verifyChecksum({'k': 'v2'}, checksum), isFalse);
    });
  });
}
