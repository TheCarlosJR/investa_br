import 'package:flutter/material.dart';

/// Faixa "dados offline / desatualizados", exibida quando o snapshot veio de
/// fallback de cache vencido (`stale == true`).
class StaleBanner extends StatelessWidget {
  const StaleBanner({required this.dataReferencia, super.key});

  /// Data do snapshot servido (já formatada, ex.: `17/06/2026`).
  final String dataReferencia;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: cs.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: cs.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sem conexão — dados de $dataReferencia podem estar '
              'desatualizados.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
