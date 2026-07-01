import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/investimento_renda_fixa.dart';
import 'renda_fixa_providers.dart';

/// Lista de investimentos de renda fixa + mutações. O `patrimonioProvider`
/// observa este provider, então invalidar a si mesmo após salvar/remover já
/// recompõe o patrimônio (sem dependência reversa de feature).
class RendaFixaListNotifier extends AsyncNotifier<List<InvestimentoRendaFixa>> {
  @override
  Future<List<InvestimentoRendaFixa>> build() =>
      ref.watch(rendaFixaRepositoryProvider).listar();

  Future<void> upsert(InvestimentoRendaFixa investimento) async {
    await ref.read(rendaFixaRepositoryProvider).salvar(investimento);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remover(String id) async {
    await ref.read(rendaFixaRepositoryProvider).remover(id);
    ref.invalidateSelf();
    await future;
  }
}

final rendaFixaListProvider = AsyncNotifierProvider<RendaFixaListNotifier,
    List<InvestimentoRendaFixa>>(RendaFixaListNotifier.new);
