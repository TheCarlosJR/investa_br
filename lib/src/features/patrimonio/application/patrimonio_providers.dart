import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/domain/money.dart';
import '../../../common/providers/core_providers.dart';
import '../../acoes/application/acoes_list_provider.dart';
import '../../conversor_taxas/domain/motor/marcacao.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../../renda_fixa/application/renda_fixa_list_provider.dart';
import '../domain/patrimonio.dart';

/// Patrimônio consolidado da carteira. Marca cada RF na curva da taxa
/// contratada (motor da F1) até hoje; ações entram pelo custo (preço médio ×
/// quantidade) enquanto não há cotação cacheada (F7). Se ainda não há snapshot
/// de indicadores, a RF degrada para o valor inicial — nunca falha por isso.
class PatrimonioNotifier extends AsyncNotifier<Patrimonio> {
  @override
  Future<Patrimonio> build() async {
    final motor = ref.watch(indicadoresMotorProvider);
    final hoje = ref.watch(clockProvider)();

    final rfs = await ref.watch(rendaFixaListProvider.future);
    final acoes = await ref.watch(acoesListProvider.future);

    final porGrupo = <GrupoAtivo, Money>{};
    var totalInvestido = Money.zero;

    for (final rf in rfs) {
      final grupo = GrupoAtivo.deRendaFixa(rf.classe);
      final atual = valorAtualRendaFixa(rf, motor, hoje);
      porGrupo[grupo] = (porGrupo[grupo] ?? Money.zero) + atual;
      totalInvestido += rf.valorInicial;
    }

    for (final acao in acoes) {
      final custo = acao.custoTotal;
      porGrupo[GrupoAtivo.acoes] =
          (porGrupo[GrupoAtivo.acoes] ?? Money.zero) + custo;
      totalInvestido += custo;
    }

    final fatias = porGrupo.entries
        .where((e) => e.value.isPositivo)
        .map((e) => FatiaPatrimonio(grupo: e.key, valorAtual: e.value))
        .toList()
      ..sort((a, b) => b.valorAtual.centavos.compareTo(a.valorAtual.centavos));

    final totalAtual = fatias.fold<Money>(
      Money.zero,
      (acc, f) => acc + f.valorAtual,
    );

    return Patrimonio(
      totalAtual: totalAtual,
      totalInvestido: totalInvestido,
      fatias: fatias,
    );
  }

  /// Recalcula (após CRUD da carteira ou refresh de indicadores).
  Future<void> recarregar() async {
    state = await AsyncValue.guard(build);
  }
}

final patrimonioProvider =
    AsyncNotifierProvider<PatrimonioNotifier, Patrimonio>(
  PatrimonioNotifier.new,
);
