import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers/core_providers.dart';
import '../data/config_repository.dart';
import '../domain/configuracao_tema.dart';

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(ref.watch(databaseProvider)),
);

/// Configuração do app (tema, locale, token brapi), persistida em sembast.
/// Expõe setters que gravam e atualizam o estado — o `app.dart` observa e
/// regenera o tema; as preferências sobrevivem entre sessões.
class ConfiguracaoNotifier extends AsyncNotifier<ConfiguracaoTema> {
  @override
  Future<ConfiguracaoTema> build() => ref.watch(configRepositoryProvider).ler();

  Future<void> _salvar(ConfiguracaoTema nova) async {
    await ref.read(configRepositoryProvider).salvar(nova);
    state = AsyncData(nova);
  }

  ConfiguracaoTema get _atual =>
      state.valueOrNull ?? ConfiguracaoTema(updatedAt: ref.read(clockProvider)());

  Future<void> setThemeMode(ThemeMode modo) =>
      _salvar(_atual.copyWith(themeMode: modo, updatedAt: ref.read(clockProvider)()));

  Future<void> setSeed(int argb) =>
      _salvar(_atual.copyWith(seedArgb: argb, updatedAt: ref.read(clockProvider)()));

  Future<void> setUseDynamic({required bool usar}) =>
      _salvar(_atual.copyWith(useDynamic: usar, updatedAt: ref.read(clockProvider)()));

  /// Define (ou limpa, com string vazia) o token brapi.
  Future<void> setBrapiToken(String token) {
    final atual = _atual;
    final limpo = token.trim();
    final nova = ConfiguracaoTema(
      themeMode: atual.themeMode,
      seedArgb: atual.seedArgb,
      useDynamic: atual.useDynamic,
      locale: atual.locale,
      brapiToken: limpo.isEmpty ? null : limpo,
      updatedAt: ref.read(clockProvider)(),
    );
    return _salvar(nova);
  }
}

final configProvider =
    AsyncNotifierProvider<ConfiguracaoNotifier, ConfiguracaoTema>(
  ConfiguracaoNotifier.new,
);

/// Token brapi corrente (runtime config). `null` enquanto a config não carregou
/// ou se o usuário não configurou — sem token a brapi só atende 4 tickers.
final brapiTokenProvider = Provider<String?>(
  (ref) => ref.watch(configProvider).valueOrNull?.brapiToken,
);
