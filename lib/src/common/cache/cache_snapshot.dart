/// Snapshot de cache com metadados de frescor.
class CacheSnapshot<T> {
  const CacheSnapshot({
    required this.dados,
    required this.dataUltimaAtualizacao,
    required this.fetchedAt,
    this.stale = false,
    this.ttlHoras = 12,
  });

  final T dados;

  /// `yyyy-MM-dd` no fuso America/Sao_Paulo.
  final String dataUltimaAtualizacao;
  final DateTime fetchedAt;

  /// `true` quando veio de fallback offline (cache vencido).
  final bool stale;
  final int ttlHoras;

  CacheSnapshot<T> copyWith({bool? stale}) => CacheSnapshot<T>(
        dados: dados,
        dataUltimaAtualizacao: dataUltimaAtualizacao,
        fetchedAt: fetchedAt,
        stale: stale ?? this.stale,
        ttlHoras: ttlHoras,
      );
}
