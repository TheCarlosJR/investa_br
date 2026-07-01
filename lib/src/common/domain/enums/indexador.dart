/// Indexador de um investimento de renda fixa pós-fixado/híbrido.
enum Indexador {
  cdi,
  selic,
  ipca,
  igpm,

  /// "sem indexador" / taxa fixa.
  prefixado;

  static Indexador fromName(String name) => Indexador.values.firstWhere(
        (e) => e.name == name,
        orElse: () => Indexador.prefixado,
      );

  /// Código da série SGS do BCB para o valor diário/mensal usado em cálculo.
  int? get serieSgs => switch (this) {
        Indexador.cdi => 12, // CDI/DI diário (% ao dia)
        Indexador.selic => 11, // SELIC diária (% ao dia)
        Indexador.ipca => 433, // IPCA mensal (%)
        Indexador.igpm => 189, // IGP-M mensal (%)
        Indexador.prefixado => null,
      };

  String get rotulo => switch (this) {
        Indexador.cdi => 'CDI',
        Indexador.selic => 'SELIC',
        Indexador.ipca => 'IPCA',
        Indexador.igpm => 'IGP-M',
        Indexador.prefixado => 'Prefixado',
      };
}
