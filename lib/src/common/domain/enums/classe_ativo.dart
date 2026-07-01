/// Classe do ativo de renda fixa. Determina a tributação via `RegraTributaria`.
enum ClasseAtivo {
  cdb,
  lci,
  lca,
  cri,
  cra,

  /// Letra de Câmbio.
  lc,

  /// Debênture comum (tributada).
  debenture,
  debentureIncentivada,
  tesouroSelic,
  tesouroPrefixado,
  tesouroIpca,
  poupanca;

  static ClasseAtivo fromName(String name) => ClasseAtivo.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ClasseAtivo.cdb,
      );

  String get rotulo => switch (this) {
        ClasseAtivo.cdb => 'CDB',
        ClasseAtivo.lci => 'LCI',
        ClasseAtivo.lca => 'LCA',
        ClasseAtivo.cri => 'CRI',
        ClasseAtivo.cra => 'CRA',
        ClasseAtivo.lc => 'Letra de Câmbio',
        ClasseAtivo.debenture => 'Debênture',
        ClasseAtivo.debentureIncentivada => 'Debênture incentivada',
        ClasseAtivo.tesouroSelic => 'Tesouro Selic',
        ClasseAtivo.tesouroPrefixado => 'Tesouro Prefixado',
        ClasseAtivo.tesouroIpca => 'Tesouro IPCA+',
        ClasseAtivo.poupanca => 'Poupança',
      };
}
