import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/cache/cache_snapshot.dart';
import '../../../common/charts/donut_carteira.dart';
import '../../../common/utils/formatters.dart';
import '../../../common/widgets/error_retry_view.dart';
import '../../../common/widgets/indicador_card.dart';
import '../../../common/widgets/stale_banner.dart';
import '../../../common/widgets/variacao_label.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../../indicadores/domain/indicador.dart';
import '../application/patrimonio_providers.dart';
import '../domain/patrimonio.dart';

/// Tela Inicial: patrimônio consolidado, cards de indicadores (cache do dia) e
/// distribuição da carteira. Estados loading/erro/vazio cobertos; pull-to-
/// refresh e botão 🔄 forçam refetch (ignoram o cache do dia).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(indicadoresProvider.notifier).atualizar();
    // patrimonioProvider observa os indicadores e se recompõe; ainda assim
    // invalidamos para reler posições eventualmente alteradas.
    ref.invalidate(patrimonioProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicadores = ref.watch(indicadoresProvider);
    final patrimonio = ref.watch(patrimonioProvider);
    final snapshot = indicadores.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investa BR'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot != null && snapshot.stale)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StaleBanner(
                  dataReferencia: Formatters.data(snapshot.fetchedAt),
                ),
              ),
            _PatrimonioHeader(patrimonio: patrimonio),
            const SizedBox(height: 24),
            _SecaoIndicadores(indicadores: indicadores, onRetry: () => _refresh(ref)),
            const SizedBox(height: 24),
            _SecaoDistribuicao(patrimonio: patrimonio),
          ],
        ),
      ),
    );
  }
}

class _PatrimonioHeader extends StatelessWidget {
  const _PatrimonioHeader({required this.patrimonio});

  final AsyncValue<Patrimonio> patrimonio;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = patrimonio.valueOrNull ?? Patrimonio.vazio;

    final variacao = switch (p.rendimentoFracao) {
      > 0 => Variacao.alta,
      < 0 => Variacao.baixa,
      _ => Variacao.estavel,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patrimônio total', style: textTheme.labelLarge),
            const SizedBox(height: 4),
            if (patrimonio.isLoading && !patrimonio.hasValue)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              Text(
                p.totalAtual.formatar(),
                style: textTheme.headlineMedium,
              ),
            const SizedBox(height: 8),
            if (!p.estaVazio)
              VariacaoLabel(
                variacao: variacao,
                texto: '${_rendimentoFmt(p)} acumulado '
                    '(${p.rendimento.formatar()})',
              )
            else
              Text(
                'Adicione investimentos para acompanhar aqui.',
                style: textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  String _rendimentoFmt(Patrimonio p) {
    final sinal = p.rendimentoFracao > 0 ? '+' : '';
    return '$sinal${(p.rendimentoFracao * 100).toStringAsFixed(2)}%';
  }
}

class _SecaoIndicadores extends StatelessWidget {
  const _SecaoIndicadores({required this.indicadores, required this.onRetry});

  final AsyncValue<CacheSnapshot<List<Indicador>>> indicadores;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final snapshot = indicadores.valueOrNull;

    final Widget conteudo;
    if (snapshot != null) {
      conteudo = _GradeIndicadores(indicadores: snapshot.dados);
    } else if (indicadores.isLoading) {
      conteudo = const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      conteudo = SizedBox(
        height: 220,
        child: ErrorRetryView(
          error: indicadores.error ?? 'Erro',
          onRetry: onRetry,
        ),
      );
    }

    final atualizadoEm = snapshot == null
        ? ''
        : ' · Atualizado em ${Formatters.dataHora(snapshot.fetchedAt)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Indicadores$atualizadoEm', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        conteudo,
      ],
    );
  }
}

class _GradeIndicadores extends StatelessWidget {
  const _GradeIndicadores({required this.indicadores});

  final List<Indicador> indicadores;

  @override
  Widget build(BuildContext context) {
    final porTipo = {for (final i in indicadores) i.tipo: i};

    final cards = <_DadoCard>[
      _cardDe(
        porTipo[TipoIndicador.selicMeta],
        'SELIC (meta)',
        casas: 2,
        sufixo: ' a.a.',
      ),
      _cardDe(porTipo[TipoIndicador.cdiDiario], 'CDI (dia)', casas: 4),
      _cardDe(
        porTipo[TipoIndicador.ipcaMensal],
        'IPCA (mês)',
        casas: 2,
        mensal: true,
      ),
      _cardDe(
        porTipo[TipoIndicador.igpmMensal],
        'IGP-M (mês)',
        casas: 2,
        mensal: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const espaco = 12.0;
        final colunas = constraints.maxWidth >= 840 ? 4 : 2;
        final largura =
            (constraints.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final c in cards)
              SizedBox(
                width: largura,
                child: IndicadorCard(
                  titulo: c.titulo,
                  valor: c.valor,
                  dataRef: c.dataRef,
                ),
              ),
          ],
        );
      },
    );
  }

  _DadoCard _cardDe(
    Indicador? ind,
    String titulo, {
    required int casas,
    String sufixo = '',
    bool mensal = false,
  }) {
    if (ind == null) {
      return _DadoCard(titulo: titulo, valor: '—', dataRef: 'sem dado');
    }
    return _DadoCard(
      titulo: titulo,
      valor: '${Formatters.percentBruto(ind.valor, casas: casas)}$sufixo',
      dataRef: mensal ? Formatters.mesAno(ind.data) : Formatters.data(ind.data),
    );
  }
}

class _DadoCard {
  const _DadoCard({
    required this.titulo,
    required this.valor,
    required this.dataRef,
  });
  final String titulo;
  final String valor;
  final String dataRef;
}

class _SecaoDistribuicao extends StatelessWidget {
  const _SecaoDistribuicao({required this.patrimonio});

  final AsyncValue<Patrimonio> patrimonio;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = patrimonio.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Distribuição da carteira', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        if (p == null || p.estaVazio)
          const _DistribuicaoVazia()
        else
          DonutCarteira(fatias: _fatiasDe(context, p)),
      ],
    );
  }

  List<FatiaDonut> _fatiasDe(BuildContext context, Patrimonio p) {
    final cs = Theme.of(context).colorScheme;
    Color cor(GrupoAtivo g) => switch (g) {
          GrupoAtivo.rendaFixa => cs.primary,
          GrupoAtivo.tesouroDireto => cs.secondary,
          GrupoAtivo.acoes => cs.tertiary,
        };
    return [
      for (final f in p.fatias)
        FatiaDonut(
          label: f.grupo.rotulo,
          valor: f.valorAtual.reais,
          valorFmt: f.valorAtual.formatar(),
          percentualFmt: '${(p.fracaoDe(f) * 100).toStringAsFixed(0)}%',
          cor: cor(f.grupo),
        ),
    ];
  }
}

/// Estado vazio inline da distribuição — dimensiona-se ao conteúdo (sem altura
/// fixa), tolerando aumento de fonte sem overflow.
class _DistribuicaoVazia extends StatelessWidget {
  const _DistribuicaoVazia();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.donut_large_outlined, size: 40, color: cs.outline),
            const SizedBox(height: 8),
            Text('Carteira vazia', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cadastre um investimento para ver a distribuição.',
              style: textTheme.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
