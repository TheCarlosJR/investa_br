import 'package:sembast/sembast.dart';

import '../../../common/persistence/local_db.dart';
import '../domain/configuracao_tema.dart';

/// CRUD do store `configuracoes` (documento singleton chave `app`).
class ConfigRepository {
  ConfigRepository(this._db);

  final DatabaseClient _db;
  final StoreRef<String, Map<String, Object?>> _store = LocalDb.configuracoes;

  Future<ConfiguracaoTema> ler() async {
    final v = await _store.record(LocalDb.configKey).get(_db);
    return v == null ? ConfiguracaoTema.padrao() : ConfiguracaoTema.fromJson(v);
  }

  Future<void> salvar(ConfiguracaoTema cfg) =>
      _store.record(LocalDb.configKey).put(_db, cfg.toJson());
}
