import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_retry_view.dart';

/// Renderiza um [AsyncValue] no padrão do app: conteúdo / loading / erro.
/// Mantém o último dado visível durante um reload (stale-while-revalidate):
/// se há valor anterior, ele continua sendo mostrado mesmo em loading/erro.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    // Preserva o conteúdo anterior enquanto recarrega ou se um reload falhar.
    if (value.hasValue) return data(value.requireValue);
    return switch (value) {
      AsyncError(:final error) => ErrorRetryView(error: error, onRetry: onRetry),
      _ => loading ?? const Center(child: CircularProgressIndicator()),
    };
  }
}
