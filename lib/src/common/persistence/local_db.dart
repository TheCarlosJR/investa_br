import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../../features/configuracoes/domain/configuracao_tema.dart';

/// Banco local NoSQL/JSON (sembast). Cada documento é um `Map<String, Object?>`
/// (JSON puro), o que torna export/import triviais.
class LocalDb {
  LocalDb();

  /// Versão do schema LOCAL (controla `onVersionChanged`). MESMA constante
  /// usada no payload de export (`schemaVersion`).
  static const int schemaVersion = 1;

  // Stores tipados (chave String, valor Map<String,Object?> == JSON puro).
  static final investimentosRf =
      stringMapStoreFactory.store('investimentos_rf');
  static final posicoesAcoes = stringMapStoreFactory.store('posicoes_acoes');
  static final cacheIndicadores =
      stringMapStoreFactory.store('cache_indicadores');
  static final configuracoes = stringMapStoreFactory.store('configuracoes');

  // Chaves fixas dos documentos singleton.
  static const String configKey = 'app';
  static const String cacheKey = 'indicadores_dia';

  late final Database db;
  bool _opened = false;

  /// Abre o banco. Em testes, passe `factory: databaseFactoryMemory` e um
  /// `path` qualquer (ex.: `'test.db'`).
  Future<Database> open({DatabaseFactory? factory, String? path}) async {
    if (_opened) return db;
    final dbFactory = factory ?? databaseFactoryIo;
    final dbPath = path ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'investa_br.db',
        );
    db = await dbFactory.openDatabase(
      dbPath,
      version: schemaVersion,
      onVersionChanged: _onVersionChanged,
    );
    _opened = true;
    return db;
  }

  Future<void> close() async {
    if (!_opened) return;
    await db.close();
    _opened = false;
  }

  Future<void> _onVersionChanged(Database db, int oldVersion, int newVersion) async {
    // Migrações incrementais, idempotentes, encadeadas por `if (oldV < N)`.
    if (oldVersion < 1) {
      // v0 -> v1: garante o documento de configuração com defaults.
      await configuracoes
          .record(configKey)
          .put(db, ConfiguracaoTema.padrao().toJson());
    }
  }
}
