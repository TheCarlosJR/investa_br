import 'package:flutter/material.dart';

import '../../domain/projecao_renda_fixa.dart';

/// Tabela de projeção de uma renda fixa (bruto, IOF, IR, líquido, taxas).
/// Reutilizada no cadastro (preview ao vivo) e no detalhe.
class ProjecaoView extends StatelessWidget {
  const ProjecaoView({
    required this.proj,
    required this.temVencimento,
    super.key,
  });

  final ProjecaoRendaFixa proj;
  final bool temVencimento;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget linha(String rotulo, String valor, {bool destaque = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(rotulo)),
              const SizedBox(width: 8),
              Text(
                valor,
                style: destaque ? textTheme.titleMedium : textTheme.bodyLarge,
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!temVencimento)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Sem vencimento: projeção ilustrativa em 1 ano '
              '(${proj.diasUteis} dias úteis).',
              style: textTheme.bodySmall,
            ),
          ),
        linha('Valor bruto', proj.valorBruto.formatar()),
        linha('Rendimento bruto', proj.rendimentoBruto.formatar()),
        linha('IOF', proj.iof.formatar()),
        linha('IR', proj.ir.formatar()),
        const Divider(),
        linha('Valor líquido', proj.valorLiquido.formatar(), destaque: true),
        linha('Líquido a.a.', proj.taxaLiquidaAnualEfetiva.formatar()),
        if (proj.taxaBrutaEquivalente != null)
          linha('Bruto equiv. (gross-up)',
              proj.taxaBrutaEquivalente!.formatar()),
      ],
    );
  }
}
