import 'package:intl/intl.dart';

/// Value object de dinheiro. Fonte da verdade em CENTAVOS (`int`) para evitar
/// erro de ponto flutuante na soma do patrimônio. Sempre BRL neste app.
class Money {
  const Money({required this.centavos, this.moeda = 'BRL'});

  /// Cria a partir de reais (UI/forms). Arredonda para o centavo.
  factory Money.reais(double valor, {String moeda = 'BRL'}) =>
      Money(centavos: (valor * 100).round(), moeda: moeda);

  factory Money.fromJson(Map<String, Object?> json) => Money(
        centavos: (json['centavos']! as num).toInt(),
        moeda: json['moeda'] as String? ?? 'BRL',
      );

  final int centavos;
  final String moeda;

  static const Money zero = Money(centavos: 0);

  double get reais => centavos / 100.0;

  bool get isPositivo => centavos > 0;

  Money operator +(Money other) {
    assert(moeda == other.moeda, 'Soma de moedas diferentes');
    return Money(centavos: centavos + other.centavos, moeda: moeda);
  }

  Money operator -(Money other) =>
      Money(centavos: centavos - other.centavos, moeda: moeda);

  Money operator *(num fator) =>
      Money(centavos: (centavos * fator).round(), moeda: moeda);

  /// Formatação pt-BR. NUNCA formatar manualmente fora daqui.
  String formatar({String locale = 'pt_BR'}) =>
      NumberFormat.currency(locale: locale, symbol: r'R$').format(reais);

  Map<String, Object?> toJson() => {'centavos': centavos, 'moeda': moeda};

  @override
  bool operator ==(Object other) =>
      other is Money && other.centavos == centavos && other.moeda == moeda;

  @override
  int get hashCode => Object.hash(centavos, moeda);

  @override
  String toString() => 'Money($centavos $moeda)';
}
