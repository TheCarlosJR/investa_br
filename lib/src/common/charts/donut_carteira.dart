import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_legend.dart';

/// Fatia pronta para plotar — já formatada. O donut NÃO recalcula finanças;
/// quem monta isto (dashboard) é o responsável pelos valores e cores.
class FatiaDonut {
  const FatiaDonut({
    required this.label,
    required this.valor,
    required this.valorFmt,
    required this.percentualFmt,
    required this.cor,
  });

  final String label;

  /// Magnitude usada na proporção do gráfico.
  final double valor;
  final String valorFmt;
  final String percentualFmt;
  final Color cor;
}

/// Donut (PieChart com furo) da distribuição da carteira, SEMPRE acompanhado de
/// legenda textual (acessibilidade). Em telas largas, gráfico e legenda lado a
/// lado; em estreitas, empilhados.
class DonutCarteira extends StatelessWidget {
  const DonutCarteira({required this.fatias, super.key});

  final List<FatiaDonut> fatias;

  @override
  Widget build(BuildContext context) {
    final semantica = 'Distribuição da carteira. '
        '${fatias.map((f) => '${f.label} ${f.percentualFmt}').join(', ')}';

    return Semantics(
      label: semantica,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 480;
          final chart = SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 48,
                sectionsSpace: 2,
                sections: [
                  for (final f in fatias)
                    PieChartSectionData(
                      value: f.valor,
                      color: f.cor,
                      title: f.percentualFmt,
                      radius: 44,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          );
          final legenda = ChartLegend(
            itens: [
              for (final f in fatias)
                LegendItem(
                  f.cor,
                  '${f.label}  ${f.valorFmt}  (${f.percentualFmt})',
                ),
            ],
          );
          return wide
              ? Row(
                  children: [
                    Expanded(child: chart),
                    Expanded(child: legenda),
                  ],
                )
              : Column(
                  children: [chart, const SizedBox(height: 12), legenda],
                );
        },
      ),
    );
  }
}
