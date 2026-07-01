import '../../../common/domain/money.dart';

/// Entidade persistida no store `posicoes_acoes`. Guarda o que o usuário
/// comprou; a cotação (preço de mercado) é dado runtime preenchido pela brapi
/// e NÃO é persistido aqui.
class PosicaoAcao {
  const PosicaoAcao({
    required this.id,
    required this.ticker,
    required this.quantidade,
    required this.precoMedio,
    required this.dataCompra,
    required this.createdAt,
    required this.updatedAt,
    this.corretora,
  });

  factory PosicaoAcao.fromJson(Map<String, Object?> json) => PosicaoAcao(
        id: json['id']! as String,
        ticker: json['ticker']! as String,
        quantidade: (json['quantidade']! as num).toInt(),
        precoMedio: Money.fromJson(json['precoMedio']! as Map<String, Object?>),
        dataCompra: DateTime.parse(json['dataCompra']! as String),
        corretora: json['corretora'] as String?,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );

  final String id;
  final String ticker;
  final int quantidade;
  final Money precoMedio;
  final DateTime dataCompra;
  final String? corretora;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Custo total da posição (preço médio × quantidade).
  Money get custoTotal => precoMedio * quantidade;

  PosicaoAcao copyWith({
    String? ticker,
    int? quantidade,
    Money? precoMedio,
    DateTime? dataCompra,
    String? corretora,
    DateTime? updatedAt,
  }) =>
      PosicaoAcao(
        id: id,
        ticker: ticker ?? this.ticker,
        quantidade: quantidade ?? this.quantidade,
        precoMedio: precoMedio ?? this.precoMedio,
        dataCompra: dataCompra ?? this.dataCompra,
        corretora: corretora ?? this.corretora,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'ticker': ticker,
        'quantidade': quantidade,
        'precoMedio': precoMedio.toJson(),
        'dataCompra': dataCompra.toIso8601String(),
        'corretora': corretora,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is PosicaoAcao &&
      other.id == id &&
      other.ticker == ticker &&
      other.quantidade == quantidade &&
      other.precoMedio == precoMedio &&
      other.dataCompra == dataCompra &&
      other.corretora == corretora &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
        id,
        ticker,
        quantidade,
        precoMedio,
        dataCompra,
        corretora,
        createdAt,
        updatedAt,
      ]);
}
