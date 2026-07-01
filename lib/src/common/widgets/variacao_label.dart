import 'package:flutter/material.dart';

/// Direção de variação de um valor. Acessibilidade: NUNCA depender só de cor —
/// sempre cor + ícone + texto (cada variante carrega ícone e descrição).
enum Variacao {
  alta(Icons.arrow_upward, 'em alta'),
  baixa(Icons.arrow_downward, 'em baixa'),
  estavel(Icons.remove, 'estável');

  const Variacao(this.icone, this.semantica);

  final IconData icone;
  final String semantica;
}

/// Rótulo de variação acessível (ícone + texto), colorido pelo `colorScheme`.
class VariacaoLabel extends StatelessWidget {
  const VariacaoLabel({required this.variacao, this.texto, super.key});

  final Variacao variacao;

  /// Texto à direita do ícone. Se nulo, usa a descrição semântica.
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = switch (variacao) {
      Variacao.alta => cs.tertiary,
      Variacao.baixa => cs.error,
      Variacao.estavel => cs.outline,
    };
    final label = texto ?? variacao.semantica;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(variacao.icone, size: 16, color: cor),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cor),
        ),
      ],
    );
  }
}
