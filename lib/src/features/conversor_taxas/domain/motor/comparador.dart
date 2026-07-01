import '../../../../common/domain/tipo_rendimento.dart';
import '../../../indicadores/domain/indicadores.dart';
import 'conversor.dart';

/// Uma opção a comparar: um tipo de rendimento contratado + flag de isenção.
class OpcaoComparacao {
  const OpcaoComparacao({
    required this.rotulo,
    required this.tipo,
    required this.isento,
  });

  /// Identificador curto exibido (ex.: `A`, `B`).
  final String rotulo;
  final TipoRendimento tipo;
  final bool isento;
}

/// Resultado por opção, na métrica única de comparação.
class ResultadoComparacao {
  const ResultadoComparacao({
    required this.rotulo,
    required this.liquidoAnual,
    required this.isento,
    this.grossUp,
  });

  final String rotulo;

  /// Rentabilidade líquida anual efetiva (decimal, base 252) após IR/IOF.
  final double liquidoAnual;
  final bool isento;

  /// Taxa bruta equivalente (gross-up) — só para isentos.
  final double? grossUp;
}

/// Aproxima dias úteis a partir de um prazo em dias corridos (252 úteis ≈ 365
/// corridos). Usado quando o comparador recebe um prazo genérico, sem datas.
int diasUteisAproximados(int prazoDias) => (prazoDias * 252 / 365).round();

/// Converte cada opção para a **rentabilidade líquida anual efetiva** (após
/// IR/IOF) e a ordena do melhor para o pior. Função PURA: indicadores e prazo
/// entram como parâmetros. O valor não altera a taxa (cancela na razão), mas é
/// repassado ao motor por consistência.
List<ResultadoComparacao> compararOpcoes({
  required Indicadores indicadores,
  required double valor,
  required int prazoDias,
  required List<OpcaoComparacao> opcoes,
}) {
  final diasUteis = diasUteisAproximados(prazoDias);
  final resultados = [
    for (final o in opcoes)
      () {
        final iBruta = iBrutaAnualDe(o.tipo, indicadores);
        final liquido = taxaLiquidaAnualEfetiva(
          vi: valor,
          iBrutaAnual: iBruta,
          prazoDias: prazoDias,
          diasUteis: diasUteis,
          isento: o.isento,
        );
        return ResultadoComparacao(
          rotulo: o.rotulo,
          liquidoAnual: liquido,
          isento: o.isento,
          grossUp: o.isento
              ? taxaBrutaEquivalenteDeIsento(liquido, prazoDias)
              : null,
        );
      }(),
  ]..sort((a, b) => b.liquidoAnual.compareTo(a.liquidoAnual));
  return resultados;
}
