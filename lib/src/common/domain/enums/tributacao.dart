import 'classe_ativo.dart';

/// Regime tributário aplicável ao rendimento.
enum Tributacao {
  /// CDB, Tesouro, LC/LF, debênture comum.
  irRegressivo,

  /// LCI/LCA/CRI/CRA/incentivada/poupança.
  isentoIrPf;

  static Tributacao fromName(String name) => Tributacao.values.firstWhere(
        (e) => e.name == name,
        orElse: () => Tributacao.irRegressivo,
      );
}

/// Alíquota de IR regressivo. Retorna 0 se [isento]. [dias] = dias corridos
/// entre aplicação e resgate/vencimento. Função PURA.
double aliquotaIrRegressivo(int dias, {required bool isento}) {
  if (isento) return 0;
  if (dias <= 180) return 0.225;
  if (dias <= 360) return 0.20;
  if (dias <= 720) return 0.175;
  return 0.15;
}

/// Alíquota de IOF regressivo (Decreto 6.306/2007). [dias] = dias corridos.
/// Zera a partir do 30º dia. Função PURA.
double aliquotaIofRegressivo(int dias) {
  if (dias >= 30) return 0;
  if (dias < 1) return 0.96; // resgate no mesmo dia: maior alíquota
  return ((30 - dias) / 30 * 100).truncate() / 100;
}

/// Regra tributária DATADA e versionada. Isola a mudança legislativa: trocar a
/// lei = nova instância com vigência diferente, sem reescrever o motor.
class RegraTributaria {
  const RegraTributaria({
    required this.versao,
    required this.vigenteDesde,
    required this.descricao,
  });

  final int versao;
  final DateTime vigenteDesde;
  final String descricao;

  /// Classes isentas de IR-PF nesta vigência.
  static const Set<ClasseAtivo> _isentas = {
    ClasseAtivo.lci,
    ClasseAtivo.lca,
    ClasseAtivo.cri,
    ClasseAtivo.cra,
    ClasseAtivo.debentureIncentivada,
    ClasseAtivo.poupanca,
  };

  bool isento(ClasseAtivo c) => _isentas.contains(c);

  Tributacao tributacaoDe(ClasseAtivo c) =>
      isento(c) ? Tributacao.isentoIrPf : Tributacao.irRegressivo;

  double aliquotaIr(ClasseAtivo c, int diasCorridos) =>
      aliquotaIrRegressivo(diasCorridos, isento: isento(c));

  double aliquotaIof(int diasCorridos) => aliquotaIofRegressivo(diasCorridos);
}

/// Regra vigente em 2026: MP 1.303/2025 caducou em out/2025 → LCI/LCA/CRI/CRA/
/// debêntures incentivadas e poupança seguem ISENTOS de IR-PF.
final regraTributariaVigente2026 = RegraTributaria(
  versao: 1,
  vigenteDesde: DateTime(2025, 10),
  descricao:
      'Em 2026: LCI/LCA/CRI/CRA, debêntures incentivadas e poupança isentos de '
      'IR-PF (MP 1.303/2025 não foi convertida em lei e caducou em out/2025). '
      'IR regressivo 22,5%/20%/17,5%/15%. IOF regressivo nos primeiros 30 dias. '
      'Valores informativos, não constituem recomendação (CVM).',
);
