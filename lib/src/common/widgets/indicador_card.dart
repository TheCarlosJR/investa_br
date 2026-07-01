import 'package:flutter/material.dart';

import 'variacao_label.dart';

/// Card de um indicador de mercado (SELIC/CDI/IPCA/IGP-M). Recebe valores já
/// formatados pt-BR. Acessível: envolto em [Semantics] com rótulo completo.
///
/// [variacao] é opcional — enquanto o app só busca o último ponto da série
/// (`/ultimos/1`), não há base para inferir alta/baixa, então o rótulo de
/// variação fica oculto em vez de exibir algo enganoso.
class IndicadorCard extends StatelessWidget {
  const IndicadorCard({
    required this.titulo,
    required this.valor,
    required this.dataRef,
    this.variacao,
    this.onTap,
    super.key,
  });

  final String titulo;
  final String valor;
  final String dataRef;
  final Variacao? variacao;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final descVar = variacao == null ? '' : ', ${variacao!.semantica}';
    return Semantics(
      button: onTap != null,
      label: '$titulo $valor, referência $dataRef$descVar',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(titulo, style: textTheme.labelMedium),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(valor, style: textTheme.titleLarge),
                  ),
                  Row(
                    children: [
                      if (variacao != null) VariacaoLabel(variacao: variacao!),
                      const Spacer(),
                      Text(
                        dataRef,
                        style: textTheme.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
