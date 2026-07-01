/// Regime de capitalização da taxa.
enum Capitalizacao {
  /// PADRÃO de mercado.
  composta,
  simples;

  static Capitalizacao fromName(String name) =>
      Capitalizacao.values.firstWhere(
        (e) => e.name == name,
        orElse: () => Capitalizacao.composta,
      );
}
