import 'package:flutter/material.dart' show ThemeMode;

/// Entidade persistida no store `configuracoes` (chave fixa `app`). Entra no
/// export. Espelha as preferências de tema e idioma.
class ConfiguracaoTema {
  const ConfiguracaoTema({
    required this.updatedAt,
    this.themeMode = ThemeMode.system,
    this.seedArgb = 0xFF1565C0,
    this.useDynamic = true,
    this.locale = 'pt_BR',
    this.brapiToken,
  });

  /// Default usado na migração `onVersionChanged` v0->v1.
  factory ConfiguracaoTema.padrao() =>
      ConfiguracaoTema(updatedAt: DateTime.now());

  factory ConfiguracaoTema.fromJson(Map<String, Object?> json) =>
      ConfiguracaoTema(
        themeMode: _themeFromName(json['themeMode'] as String? ?? 'system'),
        seedArgb: (json['seedArgb'] as num?)?.toInt() ?? 0xFF1565C0,
        useDynamic: json['useDynamic'] as bool? ?? true,
        locale: json['locale'] as String? ?? 'pt_BR',
        brapiToken: json['brapiToken'] as String?,
        updatedAt: json['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(json['updatedAt']! as String),
      );

  final ThemeMode themeMode;

  /// Cor-semente (ARGB int).
  final int seedArgb;

  /// Material You quando disponível.
  final bool useDynamic;
  final String locale;

  /// Token gratuito da brapi (runtime config; sem token, só PETR4/VALE3/MGLU3/
  /// ITUB4). Edição na tela de Ajustes (F8).
  final String? brapiToken;
  final DateTime updatedAt;

  static ThemeMode _themeFromName(String name) => ThemeMode.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ThemeMode.system,
      );

  ConfiguracaoTema copyWith({
    ThemeMode? themeMode,
    int? seedArgb,
    bool? useDynamic,
    String? locale,
    String? brapiToken,
    DateTime? updatedAt,
  }) =>
      ConfiguracaoTema(
        themeMode: themeMode ?? this.themeMode,
        seedArgb: seedArgb ?? this.seedArgb,
        useDynamic: useDynamic ?? this.useDynamic,
        locale: locale ?? this.locale,
        brapiToken: brapiToken ?? this.brapiToken,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'seedArgb': seedArgb,
        'useDynamic': useDynamic,
        'locale': locale,
        if (brapiToken != null) 'brapiToken': brapiToken,
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is ConfiguracaoTema &&
      other.themeMode == themeMode &&
      other.seedArgb == seedArgb &&
      other.useDynamic == useDynamic &&
      other.locale == locale &&
      other.brapiToken == brapiToken &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(themeMode, seedArgb, useDynamic, locale, brapiToken, updatedAt);
}
