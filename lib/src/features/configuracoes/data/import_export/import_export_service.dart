import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';

import '../../../../common/persistence/local_db.dart';
import 'backup_codec.dart';
import 'backup_validation.dart';
import 'import_modo.dart';
import 'payload_migrator.dart';

enum _Op { insert, update, skip }

/// Serviço de export/import do backup completo (renda fixa, ações e
/// preferências) em um arquivo JSON único.
///
/// A lógica pura — [montarPayload] e [aplicarImport] — é testável com um banco
/// `databaseFactoryMemory`. A escrita/leitura de arquivo usa `dart:io` e também
/// é testável com diretórios temporários. A escolha de caminho/compartilhamento
/// (file_picker / share_plus) fica na camada de UI (fase de Ajustes).
class ImportExportService {
  ImportExportService(this._db, {this.appVersion = '1.0.0'});

  final Database _db;
  final String appVersion;

  // ---------------- EXPORT ----------------

  /// Monta o payload completo com cabeçalho + checksum. `cache_indicadores` é
  /// intencionalmente OMITIDO (dado derivado).
  Future<Map<String, Object?>> montarPayload({DateTime? exportedAt}) async {
    final inv = await LocalDb.investimentosRf.find(_db);
    final acoes = await LocalDb.posicoesAcoes.find(_db);
    final cfg = await LocalDb.configuracoes.record(LocalDb.configKey).get(_db);

    final data = <String, Object?>{
      'investimentos_rf': inv.map((r) => r.value).toList(),
      'posicoes_acoes': acoes.map((r) => r.value).toList(),
      'configuracoes': {'app': cfg},
    };

    return {
      'app': 'investa_br',
      'schemaVersion': LocalDb.schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'appVersion': appVersion,
      'checksum': buildChecksum(data),
      'data': data,
    };
  }

  /// Escreve o backup indentado em [dirPath] e retorna o arquivo criado.
  Future<File> escreverBackup(String dirPath, {DateTime? agora}) async {
    final payload = await montarPayload(exportedAt: agora);
    final file = File(p.join(dirPath, 'investa_br_backup_${_stamp(agora)}.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file;
  }

  // ---------------- IMPORT ----------------

  /// Lê o arquivo, decodifica e aplica via [aplicarImport].
  Future<ImportResultado> importarDeArquivo(
    String filePath, {
    ModoImport modo = ModoImport.replace,
  }) async {
    final content = await File(filePath).readAsString();
    final Map<String, Object?> root;
    try {
      root = jsonDecode(content) as Map<String, Object?>;
    } on FormatException {
      throw const BackupInvalido('Arquivo JSON inválido.');
    }
    return aplicarImport(root, modo: modo);
  }

  /// Aplica um backup já decodificado. 4 gates de validação ANTES de qualquer
  /// escrita; aplicação em transação atômica (rollback automático em exceção).
  Future<ImportResultado> aplicarImport(
    Map<String, Object?> root, {
    ModoImport modo = ModoImport.replace,
  }) async {
    // GATE 1: identidade.
    if (root['app'] != 'investa_br') {
      throw const BackupInvalido('Arquivo não é um backup do Investa BR.');
    }
    // GATE 2: versão.
    final fileVersion = (root['schemaVersion'] as num?)?.toInt();
    if (fileVersion == null) {
      throw const BackupInvalido('Campo "schemaVersion" ausente.');
    }
    if (fileVersion > LocalDb.schemaVersion) {
      throw BackupVersaoMaisNova(fileVersion, LocalDb.schemaVersion);
    }
    final data = root['data'] as Map<String, Object?>?;
    if (data == null) {
      throw const BackupInvalido('Bloco "data" ausente.');
    }
    // GATE 3: integridade (checksum obrigatório).
    final checksum = root['checksum'];
    if (checksum is! String || !verifyChecksum(data, checksum)) {
      throw const BackupCorrompido('Checksum não confere; backup corrompido.');
    }
    // GATE 4: estrutura/tipos.
    validarEstrutura(data);

    final migrated = migratePayload(data, fileVersion, LocalDb.schemaVersion);
    final invList = (migrated['investimentos_rf'] as List?) ?? const [];
    final acoesList = (migrated['posicoes_acoes'] as List?) ?? const [];
    final cfg = (migrated['configuracoes'] as Map?)?['app'];

    var inseridos = 0;
    var atualizados = 0;
    var ignorados = 0;

    await _db.transaction((txn) async {
      if (modo == ModoImport.replace) {
        await LocalDb.investimentosRf.delete(txn);
        await LocalDb.posicoesAcoes.delete(txn);
      }
      for (final raw in invList) {
        switch (await _aplicarDoc(
            txn, LocalDb.investimentosRf, raw as Map<Object?, Object?>, modo)) {
          case _Op.insert:
            inseridos++;
          case _Op.update:
            atualizados++;
          case _Op.skip:
            ignorados++;
        }
      }
      for (final raw in acoesList) {
        switch (await _aplicarDoc(
            txn, LocalDb.posicoesAcoes, raw as Map<Object?, Object?>, modo)) {
          case _Op.insert:
            inseridos++;
          case _Op.update:
            atualizados++;
          case _Op.skip:
            ignorados++;
        }
      }
      if (cfg != null) {
        await LocalDb.configuracoes
            .record(LocalDb.configKey)
            .put(txn, Map<String, Object?>.from(cfg as Map));
      }
    });

    return ImportResultado.ok(
      modo: modo,
      inseridos: inseridos,
      atualizados: atualizados,
      ignorados: ignorados,
    );
  }

  /// MERGE por id com last-write-wins via `updatedAt`.
  Future<_Op> _aplicarDoc(
    DatabaseClient txn,
    StoreRef<String, Map<String, Object?>> store,
    Map<Object?, Object?> raw,
    ModoImport modo,
  ) async {
    final doc = Map<String, Object?>.from(raw);
    final id = doc['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const BackupInvalido('Documento sem "id".');
    }
    if (modo == ModoImport.replace) {
      await store.record(id).put(txn, doc); // store já foi limpa
      return _Op.insert;
    }
    final atual = await store.record(id).get(txn);
    if (atual == null) {
      await store.record(id).put(txn, doc);
      return _Op.insert;
    }
    final atualU = DateTime.tryParse(atual['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final novoU = DateTime.tryParse(doc['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (novoU.isAfter(atualU)) {
      await store.record(id).put(txn, doc); // arquivo mais novo vence
      return _Op.update;
    }
    return _Op.skip; // registro local igual ou mais novo: preserva
  }

  String _stamp(DateTime? agora) {
    final d = agora ?? DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p2(d.month)}${p2(d.day)}_'
        '${p2(d.hour)}${p2(d.minute)}${p2(d.second)}';
  }
}
