import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/providers/core_providers.dart';
import 'package:investa_br/src/features/configuracoes/application/config_providers.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  final now = DateTime.utc(2026, 6, 18, 12);

  test('preferências de tema persistem entre sessões', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('cfg.db');
    addTearDown(() async => db.close());

    ProviderContainer novaSessao() {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    // Sessão 1: altera e grava.
    final s1 = novaSessao();
    await s1.read(configProvider.future);
    await s1.read(configProvider.notifier).setThemeMode(ThemeMode.dark);
    await s1.read(configProvider.notifier).setSeed(0xFF2E7D32);
    await s1.read(configProvider.notifier).setUseDynamic(usar: false);
    await s1.read(configProvider.notifier).setBrapiToken('tok_x');

    // Sessão 2: relê do mesmo banco.
    final s2 = novaSessao();
    final cfg = await s2.read(configProvider.future);
    expect(cfg.themeMode, ThemeMode.dark);
    expect(cfg.seedArgb, 0xFF2E7D32);
    expect(cfg.useDynamic, isFalse);
    expect(cfg.brapiToken, 'tok_x');
  });

  test('token brapi alimenta o brapiTokenProvider', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('cfg2.db');
    addTearDown(() async => db.close());
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);

    await c.read(configProvider.future);
    expect(c.read(brapiTokenProvider), isNull);

    await c.read(configProvider.notifier).setBrapiToken('abc');
    expect(c.read(brapiTokenProvider), 'abc');
  });
}
