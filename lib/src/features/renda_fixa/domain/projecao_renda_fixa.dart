import '../../../common/domain/money.dart';
import '../../../common/domain/percentual.dart';

/// Resultado DERIVADO do motor de cálculo (não persistido).
class ProjecaoRendaFixa {
  const ProjecaoRendaFixa({
    required this.valorBruto,
    required this.rendimentoBruto,
    required this.iof,
    required this.ir,
    required this.valorLiquido,
    required this.taxaLiquidaAnualEfetiva,
    required this.diasUteis,
    required this.diasCorridos,
    this.taxaBrutaEquivalente,
  });

  final Money valorBruto;
  final Money rendimentoBruto;
  final Money iof;
  final Money ir;
  final Money valorLiquido;

  /// Rentabilidade líquida anual efetiva (base 252) — métrica do comparador.
  final Percentual taxaLiquidaAnualEfetiva;

  /// Gross-up: só para produtos isentos (quanto um tributável precisaria render).
  final Percentual? taxaBrutaEquivalente;

  final int diasUteis;
  final int diasCorridos;

  @override
  bool operator ==(Object other) =>
      other is ProjecaoRendaFixa &&
      other.valorBruto == valorBruto &&
      other.rendimentoBruto == rendimentoBruto &&
      other.iof == iof &&
      other.ir == ir &&
      other.valorLiquido == valorLiquido &&
      other.taxaLiquidaAnualEfetiva == taxaLiquidaAnualEfetiva &&
      other.taxaBrutaEquivalente == taxaBrutaEquivalente &&
      other.diasUteis == diasUteis &&
      other.diasCorridos == diasCorridos;

  @override
  int get hashCode => Object.hashAll([
        valorBruto,
        rendimentoBruto,
        iof,
        ir,
        valorLiquido,
        taxaLiquidaAnualEfetiva,
        taxaBrutaEquivalente,
        diasUteis,
        diasCorridos,
      ]);
}
