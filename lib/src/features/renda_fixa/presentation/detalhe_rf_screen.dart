import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/utils/formatters.dart';
import '../../../common/widgets/empty_state.dart';
import '../../conversor_taxas/domain/motor/projetar.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../application/renda_fixa_list_provider.dart';
import '../domain/investimento_renda_fixa.dart';
import '../domain/taxa_descricao.dart';
import 'widgets/projecao_view.dart';

/// Detalhe de uma renda fixa: dados contratados + projeção completa (motor F1)
/// até o vencimento. Ações de editar/excluir no topo.
class DetalheRfScreen extends ConsumerWidget {
  const DetalheRfScreen({required this.id, this.inicial, super.key});

  final String id;

  /// Passado via `extra` na navegação (evita reler do banco).
  final InvestimentoRendaFixa? inicial;

  InvestimentoRendaFixa? _buscar(List<InvestimentoRendaFixa>? lista) {
    if (lista == null) return null;
    for (final e in lista) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(rendaFixaListProvider).valueOrNull;
    final rf = inicial ?? _buscar(lista);

    if (rf == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Investimento')),
        body: const EmptyState(
          icone: Icons.search_off,
          titulo: 'Investimento não encontrado',
          descricao: 'Pode ter sido removido.',
        ),
      );
    }

    final motor = ref.watch(indicadoresMotorProvider);
    final resgate = rf.dataVencimento ??
        DateTime(rf.dataInicio.year + 1, rf.dataInicio.month, rf.dataInicio.day);

    return Scaffold(
      appBar: AppBar(
        title: Text(rf.apelido),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/carteira/rf/${rf.id}/editar', extra: rf),
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _excluir(context, ref, rf),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Ficha(rf: rf),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Projeção',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (motor == null)
                    Text(
                      'Indicadores do dia indisponíveis — projeção aparece '
                      'quando o snapshot carregar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ProjecaoView(
                      proj: projetar(
                        investimento: rf,
                        indicadores: motor,
                        dataResgate: resgate,
                      ),
                      temVencimento: rf.dataVencimento != null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    InvestimentoRendaFixa rf,
  ) async {
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir'),
        content: Text('Remover "${rf.apelido}" da carteira?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(rendaFixaListProvider.notifier).remover(rf.id);
      if (router.canPop()) router.pop();
    }
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.rf});

  final InvestimentoRendaFixa rf;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget linha(String r, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(r, style: textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Text(v, style: textTheme.bodyLarge),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            linha('Classe', rf.classe.rotulo),
            linha('Taxa', descreverTaxa(rf.taxa.tipoRendimento)),
            linha('Valor inicial', rf.valorInicial.formatar()),
            linha('Base de dias', '${rf.taxa.baseDias.dias}'),
            linha('Início', Formatters.data(rf.dataInicio)),
            linha(
              'Vencimento',
              rf.dataVencimento == null
                  ? 'Sem vencimento'
                  : Formatters.data(rf.dataVencimento!),
            ),
            if (rf.emissor?.razaoSocial != null)
              linha('Emissor', rf.emissor!.razaoSocial!),
          ],
        ),
      ),
    );
  }
}
