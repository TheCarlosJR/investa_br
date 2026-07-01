import 'dart:math';

/// Motor de juros — funções PURAS e determinísticas (sem I/O, sem DateTime.now).
/// Todas as taxas anuais são decimais (0.1440 = 14,40% a.a.).

/// Fator diário base 252 a partir de taxa anual (decimal).
double fatorDiario252(double iAnual) => pow(1 + iAnual, 1 / 252).toDouble();

/// VF base 252 dias úteis (juros compostos) — PADRÃO do app.
double vfBase252(double vi, double iAnual, int diasUteis) =>
    vi * pow(1 + iAnual, diasUteis / 252).toDouble();

/// VF base 360 dias corridos (comercial).
double vfBase360(double vi, double iAnual, int diasCorridos) =>
    vi * pow(1 + iAnual, diasCorridos / 360).toDouble();

/// VF base 365 dias corridos (ano civil).
double vfBase365(double vi, double iAnual, int diasCorridos) =>
    vi * pow(1 + iAnual, diasCorridos / 365).toDouble();

/// VF de pós-fixado em % do CDI (projeção com CDI constante). [pct] = 1.10
/// para 110% do CDI.
double vfPercentualCdi(double vi, double cdiAnual, double pct, int diasUteis) =>
    vi * pow(1 + cdiAnual, pct * diasUteis / 252).toDouble();

/// VF de pós-fixado em % da SELIC (projeção com SELIC constante).
double vfPercentualSelic(
  double vi,
  double selicAnual,
  double pct,
  int diasUteis,
) =>
    vi * pow(1 + selicAnual, pct * diasUteis / 252).toDouble();

/// VF híbrido IPCA+/IGP-M+: principal corrigido pelo índice acumulado * juro
/// real composto base 252.
double vfHibrido(
  double vi,
  double indiceAcumulado,
  double taxaReal,
  int diasUteis,
) =>
    vi * (1 + indiceAcumulado) * pow(1 + taxaReal, diasUteis / 252).toDouble();

/// VF de "percentual puro" composto sobre [nPeriodos].
double vfPercentualPuroComposto(double vi, double taxaPeriodo, double nPeriodos) =>
    vi * pow(1 + taxaPeriodo, nPeriodos).toDouble();

/// VF de "percentual puro" simples sobre [nPeriodos].
double vfPercentualPuroSimples(double vi, double taxaPeriodo, double nPeriodos) =>
    vi * (1 + taxaPeriodo * nPeriodos);

/// VF acumulado dia a dia para % do CDI usando a série diária real (histórico
/// exato). [cdisDiarios] = taxas DI diárias (anuais, decimal) de cada dia útil.
double vfPercentualCdiHistorico(
  double vi,
  List<double> cdisDiarios,
  double pct,
) {
  var fator = 1.0;
  for (final cdiDia in cdisDiarios) {
    final fatorDiaCdi = pow(1 + cdiDia, 1 / 252).toDouble();
    final fatorAplicado = (fatorDiaCdi - 1) * pct + 1;
    fator *= fatorAplicado;
  }
  return vi * fator;
}
