import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/common/persistence/local_db.dart';
import 'package:investa_br/src/features/acoes/data/posicoes_acoes_repository.dart';
import 'package:investa_br/src/features/acoes/domain/posicao_acao.dart';
import 'package:investa_br/src/features/configuracoes/data/import_export/backup_codec.dart';
import 'package:investa_br/src/features/configuracoes/data/import_export/backup_validation.dart';
import 'package:investa_br/src/features/configuracoes/data/import_export/import_export_service.dart';
import 'package:investa_br/src/features/configuracoes/data/import_export/import_modo.dart';
import 'package:investa_br/src/features/renda_fixa/data/renda_fixa_repository.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';
import 'package:sembast/sembast_memory.dart';

Future<Database> _mem() =>
    LocalDb().open(factory: newDatabaseFactoryMemory(), path: 'test.db');

InvestimentoRendaFixa _rf(String id, {DateTime? updatedAt, String apelido = 'cdb'}) =>
    InvestimentoRendaFixa(
      id: id,
      classe: ClasseAtivo.cdb,
      apelido: apelido,
      valorInicial: Money.reais(1000),
      taxa: const TaxaContratada(
        tipoRendimento: Prefixado(taxaAnual: Percentual(fracao: 0.10)),
      ),
      dataInicio: DateTime(2026, 1, 2),
      createdAt: DateTime(2026, 1, 2),
      updatedAt: updatedAt ?? DateTime(2026, 1, 2),
    );

PosicaoAcao _acao(String id) => PosicaoAcao(
      id: id,
      ticker: 'PETR4',
      quantidade: 100,
      precoMedio: Money.reais(38),
      dataCompra: DateTime(2026, 5, 2),
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );

Map<String, Object?> _payload({
  List<Map<String, Object?>> rf = const [],
  List<Map<String, Object?>> acoes = const [],
  Map<String, Object?>? cfg,
  int version = 1,
  String app = 'investa_br',
}) {
  final data = <String, Object?>{
    'investimentos_rf': rf,
    'posicoes_acoes': acoes,
    'configuracoes': {'app': cfg},
  };
  return {
    'app': app,
    'schemaVersion': version,
    'exportedAt': '2026-06-17T10:00:00.000',
    'appVersion': '1.0.0',
    'checksum': buildChecksum(data),
    'data': data,
  };
}

void main() {
  test('round-trip REPLACE: estado final == backup e checksum confere', () async {
    final srcDb = await _mem();
    await RendaFixaRepository(srcDb).salvar(_rf('rf1'));
    await RendaFixaRepository(srcDb).salvar(_rf('rf2'));
    await PosicoesAcoesRepository(srcDb).salvar(_acao('ac1'));

    final payload = await ImportExportService(srcDb).montarPayload();
    expect(
      verifyChecksum(
        payload['data']! as Map<String, Object?>,
        payload['checksum']! as String,
      ),
      isTrue,
    );

    final destDb = await _mem();
    final res = await ImportExportService(destDb).aplicarImport(payload);
    expect(res.inseridos, 3);
    expect(await RendaFixaRepository(destDb).contar(), 2);
    expect(await RendaFixaRepository(destDb).obter('rf1'), _rf('rf1'));
    expect(await PosicoesAcoesRepository(destDb).contar(), 1);
  });

  test('REPLACE remove registros locais ausentes no arquivo', () async {
    final destDb = await _mem();
    await RendaFixaRepository(destDb).salvar(_rf('local-x'));
    await ImportExportService(destDb).aplicarImport(_payload(rf: [_rf('rf1').toJson()]));
    expect(await RendaFixaRepository(destDb).obter('local-x'), isNull);
    expect(await RendaFixaRepository(destDb).obter('rf1'), isNotNull);
  });

  test('MERGE: last-write-wins por updatedAt', () async {
    final destDb = await _mem();
    await RendaFixaRepository(destDb).salvar(_rf('A', updatedAt: DateTime(2026)));
    await RendaFixaRepository(destDb).salvar(_rf('C', updatedAt: DateTime(2026, 6)));

    final payload = _payload(rf: [
      _rf('A', updatedAt: DateTime(2026, 2), apelido: 'A-novo').toJson(),
      _rf('B', updatedAt: DateTime(2026, 3)).toJson(),
      _rf('C', updatedAt: DateTime(2026)).toJson(), // mais antigo -> skip
    ]);

    final res =
        await ImportExportService(destDb).aplicarImport(payload, modo: ModoImport.merge);
    expect(res.inseridos, 1); // B
    expect(res.atualizados, 1); // A
    expect(res.ignorados, 1); // C
    final repo = RendaFixaRepository(destDb);
    expect((await repo.obter('A'))!.apelido, 'A-novo');
    expect(await repo.obter('B'), isNotNull);
    expect((await repo.obter('C'))!.updatedAt, DateTime(2026, 6));
  });

  test('checksum adulterado -> BackupCorrompido e nenhuma escrita', () async {
    final destDb = await _mem();
    final valid = _payload(rf: [_rf('rf1').toJson()]);
    final tampered = <String, Object?>{
      ...valid,
      'data': <String, Object?>{
        ...valid['data']! as Map<String, Object?>,
        'investimentos_rf': [_rf('rf1').toJson(), _rf('rf2').toJson()],
      },
    };
    await expectLater(
      ImportExportService(destDb).aplicarImport(tampered),
      throwsA(isA<BackupCorrompido>()),
    );
    expect(await RendaFixaRepository(destDb).contar(), 0);
  });

  test('schemaVersion maior que o app -> BackupVersaoMaisNova', () async {
    final destDb = await _mem();
    await expectLater(
      ImportExportService(destDb)
          .aplicarImport(_payload(rf: [_rf('rf1').toJson()], version: 2)),
      throwsA(isA<BackupVersaoMaisNova>()),
    );
    expect(await RendaFixaRepository(destDb).contar(), 0);
  });

  test('app diferente -> BackupInvalido', () async {
    final destDb = await _mem();
    await expectLater(
      ImportExportService(destDb)
          .aplicarImport(_payload(rf: [_rf('rf1').toJson()], app: 'outro')),
      throwsA(isA<BackupInvalido>()),
    );
  });

  test('cache_indicadores não entra no export', () async {
    final srcDb = await _mem();
    await LocalDb.cacheIndicadores
        .record(LocalDb.cacheKey)
        .put(srcDb, {'foo': 'bar'});
    await RendaFixaRepository(srcDb).salvar(_rf('rf1'));
    final payload = await ImportExportService(srcDb).montarPayload();
    final data = payload['data']! as Map<String, Object?>;
    expect(data.containsKey('cache_indicadores'), isFalse);
  });

  test('rollback atômico: doc inválido no meio (REPLACE)', () async {
    final destDb = await _mem();
    await RendaFixaRepository(destDb).salvar(_rf('X'));

    final data = <String, Object?>{
      'investimentos_rf': [
        _rf('rf1').toJson(),
        <String, Object?>{'id': ''}, // passa estrutura, falha na aplicação
      ],
      'posicoes_acoes': <Object?>[],
      'configuracoes': {'app': null},
    };
    final payload = <String, Object?>{
      'app': 'investa_br',
      'schemaVersion': 1,
      'exportedAt': '2026-06-17T10:00:00.000',
      'appVersion': '1.0.0',
      'checksum': buildChecksum(data),
      'data': data,
    };

    await expectLater(
      ImportExportService(destDb).aplicarImport(payload),
      throwsA(isA<BackupInvalido>()),
    );
    // Rollback: X preservado, rf1 não inserido.
    expect(await RendaFixaRepository(destDb).obter('X'), isNotNull);
    expect(await RendaFixaRepository(destDb).obter('rf1'), isNull);
  });

  test('round-trip via arquivo (.json)', () async {
    final srcDb = await _mem();
    await RendaFixaRepository(srcDb).salvar(_rf('rf1'));
    final dir = Directory.systemTemp.createTempSync('investa_br_test');
    try {
      final file = await ImportExportService(srcDb)
          .escreverBackup(dir.path, agora: DateTime(2026, 6, 17, 10));
      expect(file.existsSync(), isTrue);

      final destDb = await _mem();
      final res = await ImportExportService(destDb).importarDeArquivo(file.path);
      expect(res.inseridos, greaterThanOrEqualTo(1));
      expect(await RendaFixaRepository(destDb).obter('rf1'), _rf('rf1'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
