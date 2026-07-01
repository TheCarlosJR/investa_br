import 'package:intl/intl.dart';

/// Value object de percentual. Fonte da verdade é a FRAÇÃO decimal
/// (`0.1450` = 14,50%; `1.10` = 110%), forma usada nas fórmulas
/// `pow(1 + i, du/252)`.
class Percentual {
  const Percentual({required this.fracao});

  /// A partir de um número percentual (14.5 -> fração 0.145).
  factory Percentual.percentual(double valor) => Percentual(fracao: valor / 100);

  /// Parse defensivo do SGS: aceita "14.50", "14,50", "0.053400".
  factory Percentual.parseSgs(String raw) =>
      Percentual.percentual(double.parse(raw.trim().replaceAll(',', '.')));

  factory Percentual.fromJson(Map<String, Object?> json) =>
      Percentual(fracao: (json['fracao']! as num).toDouble());

  final double fracao;

  static const Percentual zero = Percentual(fracao: 0);

  double get aPercentual => fracao * 100;

  /// Formatação pt-BR. 0.145 -> "14,50%".
  String formatar({int casas = 2, String locale = 'pt_BR'}) =>
      NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: casas)
          .format(fracao);

  Map<String, Object?> toJson() => {'fracao': fracao};

  @override
  bool operator ==(Object other) =>
      other is Percentual && other.fracao == fracao;

  @override
  int get hashCode => fracao.hashCode;

  @override
  String toString() => 'Percentual(${aPercentual.toStringAsFixed(4)}%)';
}
