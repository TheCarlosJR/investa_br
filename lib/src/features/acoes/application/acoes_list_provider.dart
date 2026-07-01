import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/posicao_acao.dart';
import 'acoes_providers.dart';

/// Lista de posições em ações + mutações. Observado pelo `patrimonioProvider`.
class AcoesListNotifier extends AsyncNotifier<List<PosicaoAcao>> {
  @override
  Future<List<PosicaoAcao>> build() =>
      ref.watch(posicoesAcoesRepositoryProvider).listar();

  Future<void> upsert(PosicaoAcao posicao) async {
    await ref.read(posicoesAcoesRepositoryProvider).salvar(posicao);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remover(String id) async {
    await ref.read(posicoesAcoesRepositoryProvider).remover(id);
    ref.invalidateSelf();
    await future;
  }
}

final acoesListProvider =
    AsyncNotifierProvider<AcoesListNotifier, List<PosicaoAcao>>(
  AcoesListNotifier.new,
);
