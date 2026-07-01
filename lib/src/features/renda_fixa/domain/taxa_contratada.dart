import '../../../common/domain/enums/base_dias.dart';
import '../../../common/domain/enums/capitalizacao.dart';
import '../../../common/domain/tipo_rendimento.dart';

/// Taxa contratada de um investimento de renda fixa. Nunca representar uma taxa
/// como `double` solto: prefixado, %CDI e IPCA+ têm matemática e tributação
/// diferentes.
class TaxaContratada {
  const TaxaContratada({
    required this.tipoRendimento,
    this.baseDias = BaseDias.duteis252,
    this.capitalizacao = Capitalizacao.composta,
  });

  factory TaxaContratada.fromJson(Map<String, Object?> json) => TaxaContratada(
        tipoRendimento: TipoRendimento.fromJson(
          json['tipoRendimento']! as Map<String, Object?>,
        ),
        baseDias: BaseDias.fromDias((json['baseDias'] as num?)?.toInt() ?? 252),
        capitalizacao:
            Capitalizacao.fromName(json['capitalizacao'] as String? ?? 'composta'),
      );

  final TipoRendimento tipoRendimento;
  final BaseDias baseDias;
  final Capitalizacao capitalizacao;

  Map<String, Object?> toJson() => {
        'tipoRendimento': tipoRendimento.toJson(),
        'baseDias': baseDias.dias,
        'capitalizacao': capitalizacao.name,
      };

  @override
  bool operator ==(Object other) =>
      other is TaxaContratada &&
      other.tipoRendimento == tipoRendimento &&
      other.baseDias == baseDias &&
      other.capitalizacao == capitalizacao;

  @override
  int get hashCode => Object.hash(tipoRendimento, baseDias, capitalizacao);
}
