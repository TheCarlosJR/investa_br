/// Fundamentos de uma ação. TODOS os campos são NULLABLE: no plano gratuito da
/// brapi vêm `null` com HTTP 200 (sem erro de auth). A UI degrada graciosamente.
class FundamentosAcao {
  const FundamentosAcao({
    this.precoLucro,
    this.precoValorPatr,
    this.dividendYield,
    this.roe,
    this.recommendationKey,
    this.targetMeanPrice,
    this.numberOfAnalystOpinions,
  });

  factory FundamentosAcao.fromJson(Map<String, Object?> json) {
    double? d(Object? v) => (v as num?)?.toDouble();
    return FundamentosAcao(
      precoLucro: d(json['precoLucro']),
      precoValorPatr: d(json['precoValorPatr']),
      dividendYield: d(json['dividendYield']),
      roe: d(json['roe']),
      recommendationKey: json['recommendationKey'] as String?,
      targetMeanPrice: d(json['targetMeanPrice']),
      numberOfAnalystOpinions: (json['numberOfAnalystOpinions'] as num?)?.toInt(),
    );
  }

  /// P/L (preço/lucro).
  final double? precoLucro;

  /// P/VP (preço/valor patrimonial).
  final double? precoValorPatr;

  /// Dividend yield (fração, ex.: 0.065 = 6,5%).
  final double? dividendYield;

  /// Return on equity (fração).
  final double? roe;

  // Campos de analista — só populados no plano PRO; tratar como ausentes.
  final String? recommendationKey;
  final double? targetMeanPrice;
  final int? numberOfAnalystOpinions;

  /// `true` quando há rating de analista (plano PRO). No free é sempre `false`.
  bool get temRatingAnalista => recommendationKey != null;

  /// `true` quando nenhum fundamento útil foi populado.
  bool get vazio =>
      precoLucro == null &&
      precoValorPatr == null &&
      dividendYield == null &&
      roe == null;

  Map<String, Object?> toJson() => {
        if (precoLucro != null) 'precoLucro': precoLucro,
        if (precoValorPatr != null) 'precoValorPatr': precoValorPatr,
        if (dividendYield != null) 'dividendYield': dividendYield,
        if (roe != null) 'roe': roe,
        if (recommendationKey != null) 'recommendationKey': recommendationKey,
        if (targetMeanPrice != null) 'targetMeanPrice': targetMeanPrice,
        if (numberOfAnalystOpinions != null)
          'numberOfAnalystOpinions': numberOfAnalystOpinions,
      };

  @override
  bool operator ==(Object other) =>
      other is FundamentosAcao &&
      other.precoLucro == precoLucro &&
      other.precoValorPatr == precoValorPatr &&
      other.dividendYield == dividendYield &&
      other.roe == roe &&
      other.recommendationKey == recommendationKey &&
      other.targetMeanPrice == targetMeanPrice &&
      other.numberOfAnalystOpinions == numberOfAnalystOpinions;

  @override
  int get hashCode => Object.hash(
        precoLucro,
        precoValorPatr,
        dividendYield,
        roe,
        recommendationKey,
        targetMeanPrice,
        numberOfAnalystOpinions,
      );
}
