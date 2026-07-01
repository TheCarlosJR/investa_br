import 'dart:math';

import '../../../../common/domain/enums/base_dias.dart';
import '../../../../common/domain/enums/tributacao.dart';
import '../../../../common/domain/money.dart';
import '../../../../common/domain/percentual.dart';
import '../../../indicadores/domain/indicadores.dart';
import '../../../renda_fixa/domain/investimento_renda_fixa.dart';
import '../../../renda_fixa/domain/projecao_renda_fixa.dart';
import 'conversor.dart';
import 'dias_uteis.dart';
import 'juros.dart';

/// Projeta um [InvestimentoRendaFixa] até [dataResgate], aplicando IOF e IR
/// conforme a [RegraTributaria] vigente. FUNÇÃO PURA: indicadores, datas e
/// feriados entram como parâmetros. A capitalização composta (base 252/360/365)
/// é usada na projeção; `Capitalizacao.simples` só se aplica no cálculo manual
/// dedicado de "percentual puro".
ProjecaoRendaFixa projetar({
  required InvestimentoRendaFixa investimento,
  required Indicadores indicadores,
  required DateTime dataResgate,
  Set<DateTime> feriados = const {},
  RegraTributaria? regra,
}) {
  final r = regra ?? regraTributariaVigente2026;
  final vi = investimento.valorInicial.reais;
  final du = diasUteisEntre(investimento.dataInicio, dataResgate, feriados);
  final dc = diasCorridosEntre(investimento.dataInicio, dataResgate);

  if (vi <= 0 || du <= 0 || dc <= 0) {
    return ProjecaoRendaFixa(
      valorBruto: investimento.valorInicial,
      rendimentoBruto: Money.zero,
      iof: Money.zero,
      ir: Money.zero,
      valorLiquido: investimento.valorInicial,
      taxaLiquidaAnualEfetiva: Percentual.zero,
      diasUteis: du,
      diasCorridos: dc,
    );
  }

  final iBruta = iBrutaAnualDe(investimento.taxa.tipoRendimento, indicadores);
  final vf = switch (investimento.taxa.baseDias) {
    BaseDias.duteis252 => vfBase252(vi, iBruta, du),
    BaseDias.corridos360 => vfBase360(vi, iBruta, dc),
    BaseDias.corridos365 => vfBase365(vi, iBruta, dc),
  };

  final rendBruto = vf - vi;
  final isento = r.isento(investimento.classe);
  final iof = aliquotaIofRegressivo(dc) * rendBruto;
  final ir = aliquotaIrRegressivo(dc, isento: isento) * (rendBruto - iof);
  final vfLiq = vi + rendBruto - iof - ir;
  final iLiqAnual = pow(vfLiq / vi, 252 / du).toDouble() - 1;

  return ProjecaoRendaFixa(
    valorBruto: Money.reais(vf),
    rendimentoBruto: Money.reais(rendBruto),
    iof: Money.reais(iof),
    ir: Money.reais(ir),
    valorLiquido: Money.reais(vfLiq),
    taxaLiquidaAnualEfetiva: Percentual(fracao: iLiqAnual),
    taxaBrutaEquivalente: isento
        ? Percentual(fracao: taxaBrutaEquivalenteDeIsento(iLiqAnual, dc))
        : null,
    diasUteis: du,
    diasCorridos: dc,
  );
}
