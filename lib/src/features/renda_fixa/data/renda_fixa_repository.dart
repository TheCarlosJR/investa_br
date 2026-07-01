import 'package:sembast/sembast.dart';

import '../../../common/persistence/local_db.dart';
import '../domain/investimento_renda_fixa.dart';

/// CRUD do store `investimentos_rf`.
class RendaFixaRepository {
  RendaFixaRepository(this._db);

  final DatabaseClient _db;
  final StoreRef<String, Map<String, Object?>> _store = LocalDb.investimentosRf;

  Future<void> salvar(InvestimentoRendaFixa inv) =>
      _store.record(inv.id).put(_db, inv.toJson());

  Future<void> remover(String id) => _store.record(id).delete(_db);

  Future<InvestimentoRendaFixa?> obter(String id) async {
    final v = await _store.record(id).get(_db);
    return v == null ? null : InvestimentoRendaFixa.fromJson(v);
  }

  Future<List<InvestimentoRendaFixa>> listar() async {
    final recs = await _store.find(_db);
    return recs.map((r) => InvestimentoRendaFixa.fromJson(r.value)).toList();
  }

  Future<int> contar() => _store.count(_db);
}
