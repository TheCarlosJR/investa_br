import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/common/persistence/local_db.dart';
import 'package:investa_br/src/features/acoes/data/posicoes_acoes_repository.dart';
import 'package:investa_br/src/features/acoes/domain/posicao_acao.dart';
import 'package:investa_br/src/features/configuracoes/data/config_repository.dart';
import 'package:investa_br/src/features/configuracoes/domain/configuracao_tema.dart';
import 'package:investa_br/src/features/renda_fixa/data/renda_fixa_repository.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';
import 'package:sembast/sembast_memory.dart';

InvestimentoRendaFixa _rf(String id) => InvestimentoRendaFixa(
      id: id,
      classe: ClasseAtivo.cdb,
      apelido: 'cdb $id',
      valorInicial: Money.reais(1000),
      taxa: const TaxaContratada(
        tipoRendimento: Prefixado(taxaAnual: Percentual(fracao: 0.10)),
      ),
      dataInicio: DateTime(2026, 1, 2),
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
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

void main() {
  late LocalDb localDb;
  late Database db;

  setUp(() async {
    localDb = LocalDb();
    db = await localDb.open(factory: newDatabaseFactoryMemory(), path: 'test.db');
  });

  tearDown(() async {
    await localDb.close();
  });

  test('open semeia a configuração padrão (migração v0->v1)', () async {
    final cfg = await ConfigRepository(db).ler();
    expect(cfg.themeMode, ThemeMode.system);
    expect(cfg.locale, 'pt_BR');
  });

  test('RendaFixaRepository CRUD', () async {
    final repo = RendaFixaRepository(db);
    await repo.salvar(_rf('rf1'));
    expect(await repo.contar(), 1);
    expect(await repo.obter('rf1'), _rf('rf1'));
    await repo.remover('rf1');
    expect(await repo.obter('rf1'), isNull);
    expect(await repo.contar(), 0);
  });

  test('PosicoesAcoesRepository CRUD', () async {
    final repo = PosicoesAcoesRepository(db);
    await repo.salvar(_acao('ac1'));
    expect(await repo.contar(), 1);
    expect(await repo.obter('ac1'), _acao('ac1'));
    await repo.remover('ac1');
    expect(await repo.obter('ac1'), isNull);
  });

  test('ConfigRepository salvar/ler', () async {
    final repo = ConfigRepository(db);
    final cfg = ConfiguracaoTema(
      themeMode: ThemeMode.dark,
      seedArgb: 0xFF112233,
      useDynamic: false,
      locale: 'en',
      updatedAt: DateTime(2026, 6, 17, 9),
    );
    await repo.salvar(cfg);
    expect(await repo.ler(), cfg);
  });
}
