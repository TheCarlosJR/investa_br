import '../../../common/domain/enums/classe_ativo.dart';
import '../../../common/domain/enums/tributacao.dart';
import '../../../common/domain/money.dart';
import 'emissor.dart';
import 'taxa_contratada.dart';

/// Entidade persistida no store `investimentos_rf`. Guarda APENAS dados
/// contratados; projeção (valor futuro, rendimento, taxa efetiva) é derivada.
class InvestimentoRendaFixa {
  const InvestimentoRendaFixa({
    required this.id,
    required this.classe,
    required this.apelido,
    required this.valorInicial,
    required this.taxa,
    required this.dataInicio,
    required this.createdAt,
    required this.updatedAt,
    this.dataVencimento,
    this.emissor,
    this.observacoes,
  });

  factory InvestimentoRendaFixa.fromJson(Map<String, Object?> json) {
    DateTime? parseOpt(Object? v) =>
        v == null ? null : DateTime.parse(v as String);
    return InvestimentoRendaFixa(
      id: json['id']! as String,
      classe: ClasseAtivo.fromName(json['classe'] as String? ?? 'cdb'),
      apelido: json['apelido'] as String? ?? '',
      valorInicial: Money.fromJson(json['valorInicial']! as Map<String, Object?>),
      taxa: TaxaContratada.fromJson(json['taxa']! as Map<String, Object?>),
      dataInicio: DateTime.parse(json['dataInicio']! as String),
      dataVencimento: parseOpt(json['dataVencimento']),
      emissor: json['emissor'] == null
          ? null
          : Emissor.fromJson(json['emissor']! as Map<String, Object?>),
      observacoes: json['observacoes'] as String?,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
  }

  final String id;
  final ClasseAtivo classe;
  final String apelido;
  final Money valorInicial;
  final TaxaContratada taxa;
  final DateTime dataInicio;

  /// `null` = liquidez diária / sem vencimento.
  final DateTime? dataVencimento;
  final Emissor? emissor;
  final String? observacoes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// DERIVADO: nunca persistido. Usa a regra tributária vigente.
  bool isento(RegraTributaria regra) => regra.isento(classe);

  Tributacao tributacao(RegraTributaria regra) => regra.tributacaoDe(classe);

  bool vigenteEm(DateTime d) =>
      !d.isBefore(dataInicio) &&
      (dataVencimento == null || !d.isAfter(dataVencimento!));

  InvestimentoRendaFixa copyWith({
    ClasseAtivo? classe,
    String? apelido,
    Money? valorInicial,
    TaxaContratada? taxa,
    DateTime? dataInicio,
    DateTime? dataVencimento,
    Emissor? emissor,
    String? observacoes,
    DateTime? updatedAt,
  }) =>
      InvestimentoRendaFixa(
        id: id,
        classe: classe ?? this.classe,
        apelido: apelido ?? this.apelido,
        valorInicial: valorInicial ?? this.valorInicial,
        taxa: taxa ?? this.taxa,
        dataInicio: dataInicio ?? this.dataInicio,
        dataVencimento: dataVencimento ?? this.dataVencimento,
        emissor: emissor ?? this.emissor,
        observacoes: observacoes ?? this.observacoes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'classe': classe.name,
        'apelido': apelido,
        'valorInicial': valorInicial.toJson(),
        'taxa': taxa.toJson(),
        'dataInicio': dataInicio.toIso8601String(),
        'dataVencimento': dataVencimento?.toIso8601String(),
        'emissor': emissor?.toJson(),
        'observacoes': observacoes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is InvestimentoRendaFixa &&
      other.id == id &&
      other.classe == classe &&
      other.apelido == apelido &&
      other.valorInicial == valorInicial &&
      other.taxa == taxa &&
      other.dataInicio == dataInicio &&
      other.dataVencimento == dataVencimento &&
      other.emissor == emissor &&
      other.observacoes == observacoes &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
        id,
        classe,
        apelido,
        valorInicial,
        taxa,
        dataInicio,
        dataVencimento,
        emissor,
        observacoes,
        createdAt,
        updatedAt,
      ]);
}
