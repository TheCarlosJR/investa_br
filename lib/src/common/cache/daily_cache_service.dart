import 'package:sembast/sembast.dart';

import 'cache_snapshot.dart';

/// Cache da "primeira requisição do dia". Chave por data (`yyyy-MM-dd`, fuso
/// America/Sao_Paulo = UTC-3 fixo desde 2019). Serve do cache se a data for de
/// hoje E dentro do TTL; senão, o repositório busca remoto e regrava.
///
/// O relógio é injetável (`now`) para tornar a lógica determinística em testes.
class DailyCacheService {
  DailyCacheService(
    this._db,
    this._store, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DatabaseClient _db;
  final StoreRef<String, Map<String, Object?>> _store;
  final DateTime Function() _now;

  /// Data corrente em America/Sao_Paulo (UTC-3), `yyyy-MM-dd`.
  String hojeSp() => _now()
      .toUtc()
      .subtract(const Duration(hours: 3))
      .toIso8601String()
      .substring(0, 10);

  /// Retorna o snapshot somente se for de hoje E dentro do TTL.
  Future<CacheSnapshot<T>?> lerSeDeHoje<T>(
    String key,
    T Function(Object? json) fromJson,
  ) async {
    final raw = await _store.record(key).get(_db);
    if (raw == null) return null;
    final mesmaData = raw['dataUltimaAtualizacao'] == hojeSp();
    final fetchedAt = DateTime.tryParse(raw['fetchedAt'] as String? ?? '');
    final ttl = Duration(hours: (raw['ttlHoras'] as num?)?.toInt() ?? 12);
    final dentroTtl =
        fetchedAt != null && _now().difference(fetchedAt) < ttl;
    if (!mesmaData || !dentroTtl) return null;
    return _hidratar(raw, fromJson);
  }

  /// Lê qualquer snapshot existente, mesmo vencido (fallback offline).
  Future<CacheSnapshot<T>?> lerQualquer<T>(
    String key,
    T Function(Object? json) fromJson,
  ) async {
    final raw = await _store.record(key).get(_db);
    return raw == null ? null : _hidratar(raw, fromJson);
  }

  Future<CacheSnapshot<T>> gravar<T>(
    String key,
    T dados, {
    required Object? Function(T) toJson,
  }) async {
    final snap = CacheSnapshot<T>(
      dados: dados,
      dataUltimaAtualizacao: hojeSp(),
      fetchedAt: _now(),
    );
    await _store.record(key).put(_db, {
      'dataUltimaAtualizacao': snap.dataUltimaAtualizacao,
      'fetchedAt': snap.fetchedAt.toIso8601String(),
      'ttlHoras': snap.ttlHoras,
      'stale': false,
      'payload': toJson(dados),
    });
    return snap;
  }

  CacheSnapshot<T> _hidratar<T>(
    Map<String, Object?> raw,
    T Function(Object? json) fromJson,
  ) =>
      CacheSnapshot<T>(
        dados: fromJson(raw['payload']),
        dataUltimaAtualizacao: raw['dataUltimaAtualizacao']! as String,
        fetchedAt: DateTime.parse(raw['fetchedAt']! as String),
        ttlHoras: (raw['ttlHoras'] as num?)?.toInt() ?? 12,
        stale: raw['stale'] as bool? ?? false,
      );
}
