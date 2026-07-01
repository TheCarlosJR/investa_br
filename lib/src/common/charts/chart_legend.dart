import 'package:flutter/material.dart';

/// Item de legenda (cor + texto). O texto deve ser auto-suficiente (label +
/// valor + %), pois a legenda é a alternativa textual acessível ao gráfico.
class LegendItem {
  const LegendItem(this.cor, this.texto);
  final Color cor;
  final String texto;
}

/// Legenda textual de um gráfico. Obrigatória ao lado de qualquer gráfico que
/// codifica dado por cor (cor sozinha falha em acessibilidade).
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.itens, super.key});

  final List<LegendItem> itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.cor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.texto,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
