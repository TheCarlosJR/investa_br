/// Base de contagem de dias para capitalização.
enum BaseDias {
  /// PADRÃO: CDB/LCI/LCA/prefixado/pós-CDI (dias úteis, convenção B3).
  duteis252,

  /// Comercial.
  corridos360,

  /// Ano civil.
  corridos365;

  static BaseDias fromDias(int dias) => switch (dias) {
        360 => BaseDias.corridos360,
        365 => BaseDias.corridos365,
        _ => BaseDias.duteis252,
      };

  int get dias => switch (this) {
        BaseDias.duteis252 => 252,
        BaseDias.corridos360 => 360,
        BaseDias.corridos365 => 365,
      };

  bool get usaDiasUteis => this == BaseDias.duteis252;
}
