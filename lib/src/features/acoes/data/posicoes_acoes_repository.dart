import 'package:sembast/sembast.dart';

import '../../../common/persistence/local_db.dart';
import '../domain/posicao_acao.dart';

/// CRUD do store `posicoes_acoes`.
class PosicoesAcoesRepository {
  PosicoesAcoesRepository(this._db);

  final DatabaseClient _db;
  final StoreRef<String, Map<String, Object?>> _store = LocalDb.posicoesAcoes;

  Future<void> salvar(PosicaoAcao posicao) =>
      _store.record(posicao.id).put(_db, posicao.toJson());

  Future<void> remover(String id) => _store.record(id).delete(_db);

  Future<PosicaoAcao?> obter(String id) async {
    final v = await _store.record(id).get(_db);
    return v == null ? null : PosicaoAcao.fromJson(v);
  }

  Future<List<PosicaoAcao>> listar() async {
    final recs = await _store.find(_db);
    return recs.map((r) => PosicaoAcao.fromJson(r.value)).toList();
  }

  Future<int> contar() => _store.count(_db);
}
