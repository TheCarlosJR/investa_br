import 'dart:math';

import '../../../../common/domain/enums/tributacao.dart';
import '../../../../common/domain/tipo_rendimento.dart';
import '../../../indicadores/domain/indicadores.dart';

/// Rentabilidade líquida anual efetiva (% a.a., base 252) de um produto.
/// FUNÇÃO PURA: todos os indicadores e prazos são parâmetros.
double taxaLiquidaAnualEfetiva({
  required double vi,
  required double iBrutaAnual,
  required int prazoDias,
  required int diasUteis,
  required bool isento,
}) {
  if (vi <= 0 || diasUteis <= 0) return 0;
  final vf = vi * pow(1 + iBrutaAnual, diasUteis / 252).toDouble();
  final rendBruto = vf - vi;
  final iof = aliquotaIofRegressivo(prazoDias) * rendBruto;
  final ir = aliquotaIrRegressivo(prazoDias, isento: isento) * (rendBruto - iof);
  final vfLiq = vi + rendBruto - iof - ir;
  return pow(vfLiq / vi, 252 / diasUteis).toDouble() - 1;
}

/// Taxa bruta equivalente (gross-up) de um produto ISENTO: quanto um produto
/// TRIBUTÁVEL precisaria render (a.a. bruto) para empatar, dado o prazo e a
/// alíquota de IR correspondente.
double taxaBrutaEquivalenteDeIsento(double iLiqAnualIsento, int prazoDias) =>
    iLiqAnualIsento / (1 - aliquotaIrRegressivo(prazoDias, isento: false));

/// Taxa anual bruta equivalente a partir do tipo de rendimento contratado e do
/// snapshot de indicadores. Pattern matching exaustivo sobre a union.
double iBrutaAnualDe(TipoRendimento tipo, Indicadores idx) => switch (tipo) {
      Prefixado(:final taxaAnual) => taxaAnual.fracao,
      Posfixado(:final indexador, :final percentualDoIndice) =>
        pow(1 + idx.anualDe(indexador), percentualDoIndice.fracao).toDouble() - 1,
      IndexadoMais(:final indexador, :final taxaReal) =>
        (1 + idx.anualDe(indexador)) * (1 + taxaReal.fracao) - 1,
      PercentualPuro(:final taxa, :final periodo) => periodo == PeriodoTaxa.aoAno
          ? taxa.fracao
          : pow(1 + taxa.fracao, 12).toDouble() - 1,
    };
