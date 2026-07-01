import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/configuracoes/domain/configuracao_tema.dart';

void main() {
  group('ConfiguracaoTema', () {
    test('round-trip JSON', () {
      final cfg = ConfiguracaoTema(
        themeMode: ThemeMode.dark,
        seedArgb: 0xFF112233,
        useDynamic: false,
        locale: 'en',
        updatedAt: DateTime(2026, 6, 17, 9),
      );
      expect(ConfiguracaoTema.fromJson(cfg.toJson()), cfg);
    });

    test('padrão tem defaults coerentes', () {
      final cfg = ConfiguracaoTema.padrao();
      expect(cfg.themeMode, ThemeMode.system);
      expect(cfg.seedArgb, 0xFF1565C0);
      expect(cfg.useDynamic, isTrue);
      expect(cfg.locale, 'pt_BR');
    });

    test('brapiToken faz round-trip e default é null', () {
      expect(ConfiguracaoTema.padrao().brapiToken, isNull);
      final cfg = ConfiguracaoTema(updatedAt: DateTime(2026, 6, 18), brapiToken: 'tok_123');
      final ida = ConfiguracaoTema.fromJson(cfg.toJson());
      expect(ida.brapiToken, 'tok_123');
      expect(ida, cfg);
    });

    test('themeMode desconhecido cai em system', () {
      final cfg = ConfiguracaoTema.fromJson({
        'themeMode': 'invalido',
        'updatedAt': '2026-06-17T09:00:00.000',
      });
      expect(cfg.themeMode, ThemeMode.system);
    });
  });
}
