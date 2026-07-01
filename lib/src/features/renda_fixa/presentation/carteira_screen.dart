import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/domain/money.dart';
import '../../../common/providers/core_providers.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/variacao_label.dart';
import '../../acoes/application/acoes_list_provider.dart';
import '../../acoes/domain/posicao_acao.dart';
import '../../conversor_taxas/domain/motor/marcacao.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../application/renda_fixa_list_provider.dart';
import '../domain/investimento_renda_fixa.dart';
import '../domain/taxa_descricao.dart';

/// Aba Carteira: posições de RF (marcadas na curva) e de ações (pelo custo até
/// a cotação ao vivo da Fase 7), em seções com totais; editar/excluir por item.
class CarteiraScreen extends ConsumerWidget {
  const CarteiraScreen({super.key});

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref, {
    required String titulo,
    required Future<void> Function() onConfirmar,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir'),
        content: Text('Remover "$titulo" da carteira?'),
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
    if (ok ?? false) await onConfirmar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rfs = ref.watch(rendaFixaListProvider).valueOrNull ?? const [];
    final acoes = ref.watch(acoesListProvider).valueOrNull ?? const [];
    final carregando = ref.watch(rendaFixaListProvider).isLoading ||
        ref.watch(acoesListProvider).isLoading;
    final motor = ref.watch(indicadoresMotorProvider);
    final hoje = ref.watch(clockProvider)();

    final vazio = rfs.isEmpty && acoes.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Carteira')),
      body: carregando && vazio
          ? const Center(child: CircularProgressIndicator())
          : vazio
              ? EmptyState(
                  icone: Icons.account_balance_wallet_outlined,
                  titulo: 'Carteira vazia',
                  descricao: 'Adicione um investimento de renda fixa ou uma '
                      'posição em ações para começar.',
                  acao: FilledButton.icon(
                    onPressed: () => context.go('/carteira/rf/novo'),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar renda fixa'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _CabecalhoSecao(
                      titulo: 'Renda Fixa',
                      contagem: rfs.length,
                      total: rfs.fold<Money>(
                        Money.zero,
                        (a, r) => a + valorAtualRendaFixa(r, motor, hoje),
                      ),
                      rotuloAdicionar: 'Adicionar RF',
                      onAdicionar: () => context.go('/carteira/rf/novo'),
                    ),
                    for (final rf in rfs)
                      _RfTile(
                        rf: rf,
                        valorAtual: valorAtualRendaFixa(rf, motor, hoje),
                        temMotor: motor != null,
                        onAbrir: () =>
                            context.push('/carteira/rf/${rf.id}', extra: rf),
                        onEditar: () => context.push(
                          '/carteira/rf/${rf.id}/editar',
                          extra: rf,
                        ),
                        onExcluir: () => _confirmarExclusao(
                          context,
                          ref,
                          titulo: rf.apelido,
                          onConfirmar: () => ref
                              .read(rendaFixaListProvider.notifier)
                              .remover(rf.id),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _CabecalhoSecao(
                      titulo: 'Ações',
                      contagem: acoes.length,
                      total: acoes.fold<Money>(
                        Money.zero,
                        (a, p) => a + p.custoTotal,
                      ),
                      rotuloAdicionar: 'Adicionar ação',
                      onAdicionar: () => context.go('/carteira/acao/novo'),
                    ),
                    for (final acao in acoes)
                      _AcaoTile(
                        acao: acao,
                        onEditar: () => context.push(
                          '/carteira/acao/${acao.id}/editar',
                          extra: acao,
                        ),
                        onExcluir: () => _confirmarExclusao(
                          context,
                          ref,
                          titulo: acao.ticker,
                          onConfirmar: () => ref
                              .read(acoesListProvider.notifier)
                              .remover(acao.id),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _CabecalhoSecao extends StatelessWidget {
  const _CabecalhoSecao({
    required this.titulo,
    required this.contagem,
    required this.total,
    required this.rotuloAdicionar,
    required this.onAdicionar,
  });

  final String titulo;
  final int contagem;
  final Money total;
  final String rotuloAdicionar;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$titulo · $contagem · ${total.formatar()}',
              style: textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: onAdicionar,
            icon: const Icon(Icons.add, size: 18),
            label: Text(rotuloAdicionar),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.onEditar, required this.onExcluir});

  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) => v == 'editar' ? onEditar() : onExcluir(),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'editar', child: Text('Editar')),
        PopupMenuItem(value: 'excluir', child: Text('Excluir')),
      ],
    );
  }
}

class _RfTile extends StatelessWidget {
  const _RfTile({
    required this.rf,
    required this.valorAtual,
    required this.temMotor,
    required this.onAbrir,
    required this.onEditar,
    required this.onExcluir,
  });

  final InvestimentoRendaFixa rf;
  final Money valorAtual;
  final bool temMotor;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rendimento = valorAtual - rf.valorInicial;
    final fracao = rf.valorInicial.centavos == 0
        ? 0.0
        : rendimento.centavos / rf.valorInicial.centavos;
    final variacao = switch (fracao) {
      > 0 => Variacao.alta,
      < 0 => Variacao.baixa,
      _ => Variacao.estavel,
    };

    return Card(
      child: ListTile(
        onTap: onAbrir,
        title: Text(rf.apelido),
        subtitle: Text('${rf.classe.rotulo} · ${descreverTaxa(rf.taxa.tipoRendimento)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(valorAtual.formatar(), style: textTheme.titleSmall),
                if (temMotor)
                  VariacaoLabel(
                    variacao: variacao,
                    texto: '${fracao >= 0 ? '+' : ''}'
                        '${(fracao * 100).toStringAsFixed(2)}%',
                  ),
              ],
            ),
            _MenuItem(onEditar: onEditar, onExcluir: onExcluir),
          ],
        ),
      ),
    );
  }
}

class _AcaoTile extends StatelessWidget {
  const _AcaoTile({
    required this.acao,
    required this.onEditar,
    required this.onExcluir,
  });

  final PosicaoAcao acao;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        title: Text(acao.ticker),
        subtitle: Text(
          '${acao.quantidade} cotas · PM ${acao.precoMedio.formatar()}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(acao.custoTotal.formatar(), style: textTheme.titleSmall),
            _MenuItem(onEditar: onEditar, onExcluir: onExcluir),
          ],
        ),
      ),
    );
  }
}
