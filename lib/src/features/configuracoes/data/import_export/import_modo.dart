/// Modo de importação de backup.
enum ModoImport {
  /// Limpa a carteira atual e usa o arquivo (restaurar/migrar).
  replace,

  /// Combina por id, last-write-wins via `updatedAt` (mesclar dispositivos).
  merge,
}

/// Resultado de uma importação.
class ImportResultado {
  const ImportResultado({
    required this.cancelado,
    this.modo,
    this.inseridos = 0,
    this.atualizados = 0,
    this.ignorados = 0,
  });

  factory ImportResultado.cancelado() =>
      const ImportResultado(cancelado: true);

  factory ImportResultado.ok({
    required ModoImport modo,
    required int inseridos,
    required int atualizados,
    required int ignorados,
  }) =>
      ImportResultado(
        cancelado: false,
        modo: modo,
        inseridos: inseridos,
        atualizados: atualizados,
        ignorados: ignorados,
      );

  final bool cancelado;
  final ModoImport? modo;
  final int inseridos;
  final int atualizados;
  final int ignorados;
}
