import 'package:flutter/material.dart';

import '../result/failure.dart';

/// Estado de erro com mensagem pt-BR + botão "Tentar de novo". Extrai a
/// mensagem amigável de um [Failure]; para erros desconhecidos, usa um texto
/// genérico (sem vazar `toString` de exceções).
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  String get _mensagem => switch (error) {
        final Failure f => f.message,
        _ => 'Algo deu errado ao carregar os dados.',
      };

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
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              _mensagem,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
