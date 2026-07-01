import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_legend.dart';

/// Item do comparador, já formatado para plotar.
class BarComparadorItem {
  const BarComparadorItem({
    required this.rotulo,
    required this.valorPercent,
    required this.valorFmt,
    required this.melhor,
  });

  final String rotulo;

  /// Valor em pontos percentuais (ex.: 13.57 para 13,57%).
  final double valorPercent;
  final String valorFmt;
  final bool melhor;
}

/// `BarChart` do ranking de rentabilidade líquida. A barra vencedora usa
/// `colorScheme.primary`; as demais, `secondaryContainer`. Acompanhado de
/// legenda textual (acessibilidade).
class BarComparador extends StatelessWidget {
  const BarComparador({required this.itens, super.key});

  final List<BarComparadorItem> itens;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxY = itens.isEmpty
        ? 1.0
        : itens.map((e) => e.valorPercent).reduce((a, b) => a > b ? a : b) * 1.2;

    final semantica = 'Ranking de rentabilidade líquida anual. '
        '${itens.map((e) => '${e.rotulo} ${e.valorFmt}').join(', ')}';

    return Semantics(
      label: semantica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 1 : maxY,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= itens.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(itens[i].rotulo),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < itens.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: itens[i].valorPercent,
                          color: itens[i].melhor
                              ? cs.primary
                              : cs.secondaryContainer,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ChartLegend(
            itens: [
              for (final item in itens)
                LegendItem(
                  item.melhor ? cs.primary : cs.secondaryContainer,
                  '${item.rotulo}  ${item.valorFmt}'
                      '${item.melhor ? '  ⭐ melhor' : ''}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
