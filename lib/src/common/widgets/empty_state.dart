import 'package:flutter/material.dart';

/// Estado vazio reutilizável (ícone + título + descrição + ação opcional).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icone,
    required this.titulo,
    this.descricao,
    this.acao,
    super.key,
  });

  final IconData icone;
  final String titulo;
  final String? descricao;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (descricao != null) ...[
              const SizedBox(height: 6),
              Text(
                descricao!,
                style: textTheme.bodyMedium?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: 16),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
