import 'enums/indexador.dart';
import 'percentual.dart';

/// Período de referência de uma taxa de "percentual puro".
enum PeriodoTaxa {
  aoMes,
  aoAno;

  static PeriodoTaxa fromName(String name) => PeriodoTaxa.values.firstWhere(
        (e) => e.name == name,
        orElse: () => PeriodoTaxa.aoAno,
      );
}

/// Tipo de rendimento contratado. Union selada: cada variante carrega dados
/// diferentes e o motor/UI fazem pattern matching exaustivo (Dart 3 `switch`).
sealed class TipoRendimento {
  const TipoRendimento();

  factory TipoRendimento.fromJson(Map<String, Object?> json) {
    final tipo = json['tipo'] as String?;
    return switch (tipo) {
      'prefixado' => Prefixado.fromJson(json),
      'posfixado' => Posfixado.fromJson(json),
      'indexado_mais' => IndexadoMais.fromJson(json),
      'percentual_puro' => PercentualPuro.fromJson(json),
      _ => throw FormatException('TipoRendimento desconhecido: $tipo'),
    };
  }

  Map<String, Object?> toJson();
}

/// Taxa fixa conhecida na compra. Ex.: 13% a.a.
final class Prefixado extends TipoRendimento {
  const Prefixado({required this.taxaAnual});

  factory Prefixado.fromJson(Map<String, Object?> json) => Prefixado(
        taxaAnual: Percentual.fromJson(json['taxaAnual']! as Map<String, Object?>),
      );

  final Percentual taxaAnual;

  @override
  Map<String, Object?> toJson() => {
        'tipo': 'prefixado',
        'taxaAnual': taxaAnual.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is Prefixado && other.taxaAnual == taxaAnual;

  @override
  int get hashCode => taxaAnual.hashCode;
}

/// Pós-fixado: PERCENTUAL de um indexador que varia (CDI/SELIC).
/// Ex.: 110% do CDI -> indexador=CDI, percentualDoIndice=1.10.
final class Posfixado extends TipoRendimento {
  const Posfixado({
    required this.indexador,
    required this.percentualDoIndice,
  });

  factory Posfixado.fromJson(Map<String, Object?> json) => Posfixado(
        indexador: Indexador.fromName(json['indexador'] as String? ?? 'cdi'),
        percentualDoIndice:
            Percentual.fromJson(json['percentualDoIndice']! as Map<String, Object?>),
      );

  final Indexador indexador;
  final Percentual percentualDoIndice;

  @override
  Map<String, Object?> toJson() => {
        'tipo': 'posfixado',
        'indexador': indexador.name,
        'percentualDoIndice': percentualDoIndice.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is Posfixado &&
      other.indexador == indexador &&
      other.percentualDoIndice == percentualDoIndice;

  @override
  int get hashCode => Object.hash(indexador, percentualDoIndice);
}

/// Híbrido: índice + juro real. Ex.: IPCA+6% -> IPCA, taxaReal=0.06.
final class IndexadoMais extends TipoRendimento {
  const IndexadoMais({required this.indexador, required this.taxaReal});

  factory IndexadoMais.fromJson(Map<String, Object?> json) => IndexadoMais(
        indexador: Indexador.fromName(json['indexador'] as String? ?? 'ipca'),
        taxaReal: Percentual.fromJson(json['taxaReal']! as Map<String, Object?>),
      );

  final Indexador indexador;
  final Percentual taxaReal;

  @override
  Map<String, Object?> toJson() => {
        'tipo': 'indexado_mais',
        'indexador': indexador.name,
        'taxaReal': taxaReal.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is IndexadoMais &&
      other.indexador == indexador &&
      other.taxaReal == taxaReal;

  @override
  int get hashCode => Object.hash(indexador, taxaReal);
}

/// Percentual puro: taxa-alvo bruta lançada manualmente, com período e
/// capitalização configuráveis.
final class PercentualPuro extends TipoRendimento {
  const PercentualPuro({required this.taxa, this.periodo = PeriodoTaxa.aoAno});

  factory PercentualPuro.fromJson(Map<String, Object?> json) => PercentualPuro(
        taxa: Percentual.fromJson(json['taxa']! as Map<String, Object?>),
        periodo: PeriodoTaxa.fromName(json['periodo'] as String? ?? 'aoAno'),
      );

  final Percentual taxa;
  final PeriodoTaxa periodo;

  @override
  Map<String, Object?> toJson() => {
        'tipo': 'percentual_puro',
        'taxa': taxa.toJson(),
        'periodo': periodo.name,
      };

  @override
  bool operator ==(Object other) =>
      other is PercentualPuro &&
      other.taxa == taxa &&
      other.periodo == periodo;

  @override
  int get hashCode => Object.hash(taxa, periodo);
}
