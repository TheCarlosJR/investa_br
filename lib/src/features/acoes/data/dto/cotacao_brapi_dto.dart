/// DTO do resultado de `GET /api/quote/{ticker}` (brapi). Campos numéricos são
/// nullable: no plano gratuito muitos vêm `null` com HTTP 200.
class CotacaoBrapiDto {
  const CotacaoBrapiDto({
    required this.symbol,
    this.longName,
    this.shortName,
    this.regularMarketPrice,
    this.regularMarketChangePercent,
    this.logourl,
    this.priceEarnings,
    this.earningsPerShare,
    this.priceToBook,
    this.dividendYield,
    this.returnOnEquity,
    this.recommendationKey,
    this.targetMeanPrice,
    this.numberOfAnalystOpinions,
  });

  factory CotacaoBrapiDto.fromJson(Map<String, Object?> json) {
    double? d(Object? v) => (v as num?)?.toDouble();
    return CotacaoBrapiDto(
      symbol: json['symbol']! as String,
      longName: json['longName'] as String?,
      shortName: json['shortName'] as String?,
      regularMarketPrice: d(json['regularMarketPrice']),
      regularMarketChangePercent: d(json['regularMarketChangePercent']),
      logourl: json['logourl'] as String?,
      priceEarnings: d(json['priceEarnings']),
      earningsPerShare: d(json['earningsPerShare']),
      priceToBook: d(json['priceToBook']),
      dividendYield: d(json['dividendYield']),
      returnOnEquity: d(json['returnOnEquity']),
      recommendationKey: json['recommendationKey'] as String?,
      targetMeanPrice: d(json['targetMeanPrice']),
      numberOfAnalystOpinions: (json['numberOfAnalystOpinions'] as num?)?.toInt(),
    );
  }

  final String symbol;
  final String? longName;
  final String? shortName;
  final double? regularMarketPrice;
  final double? regularMarketChangePercent;
  final String? logourl;
  final double? priceEarnings;
  final double? earningsPerShare;
  final double? priceToBook;
  final double? dividendYield;
  final double? returnOnEquity;
  final String? recommendationKey;
  final double? targetMeanPrice;
  final int? numberOfAnalystOpinions;
}
