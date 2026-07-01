import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/cache/cache_snapshot.dart';
import '../../../common/domain/money.dart';
import '../../../common/domain/percentual.dart';
import '../../../common/utils/formatters.dart';
import '../../../common/widgets/error_retry_view.dart';
import '../../../common/widgets/stale_banner.dart';
import '../../../common/widgets/variacao_label.dart';
import '../application/cotacao_providers.dart';
import '../domain/cotacao.dart';
import '../domain/fundamentos_acao.dart';
import '../domain/sinais_acao.dart';

/// Detalhe de uma ação: cotação, fundamentos (com `—` quando ausentes no plano
/// gratuito) e sinais próprios. O gráfico de candles fica para uma iteração
/// futura (precisa do histórico da brapi).
class DetalheAcaoScreen extends ConsumerWidget {
  const DetalheAcaoScreen({required this.ticker, super.key});

  final String ticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickerUp = ticker.toUpperCase();
    final cotacaoAsync = ref.watch(cotacaoProvider(tickerUp));

    return Scaffold(
      appBar: AppBar(
        title: Text(tickerUp),
        actions: [
          IconButton(
            tooltip: 'Adicionar à carteira',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/carteira/acao/novo'),
          ),
        ],
      ),
      body: cotacaoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () => ref.invalidate(cotacaoProvider(tickerUp)),
        ),
        data: (snap) => _Conteudo(snapshot: snap),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.snapshot});

  final CacheSnapshot<Cotacao> snapshot;

  @override
  Widget build(BuildContext context) {
    final c = snapshot.dados;
    final stale = snapshot.stale;
    final textTheme = Theme.of(context).textTheme;
    final variacao = switch (c.variacaoDiaPct.fracao) {
      > 0 => Variacao.alta,
      < 0 => Variacao.baixa,
      _ => Variacao.estavel,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StaleBanner(
              dataReferencia: Formatters.dataHora(c.atualizadoEm),
            ),
          ),
        if (c.nomeEmpresa != null)
          Text(c.nomeEmpresa!, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          spacing: 12,
          children: [
            Text(c.preco.formatar(), style: textTheme.headlineSmall),
            VariacaoLabel(
              variacao: variacao,
              texto: c.variacaoDiaPct.formatar(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Fundamentos(fundamentos: c.fundamentos),
        const SizedBox(height: 24),
        _Sinais(fundamentos: c.fundamentos),
      ],
    );
  }
}

class _Fundamentos extends StatelessWidget {
  const _Fundamentos({required this.fundamentos});

  final FundamentosAcao? fundamentos;

  @override
  Widget build(BuildContext context) {
    final f = fundamentos;
    String num2(double? v) => v == null ? '—' : v.toStringAsFixed(2).replaceAll('.', ',');
    String pct(double? v) => v == null ? '—' : Percentual(fracao: v).formatar();
    String preco(double? v) => v == null ? '—' : Money.reais(v).formatar();

    final itens = <(String, String)>[
      ('P/L', num2(f?.precoLucro)),
      ('P/VP', num2(f?.precoValorPatr)),
      ('Dividend yield', pct(f?.dividendYield)),
      ('ROE', pct(f?.roe)),
      ('Preço-alvo (analistas)', preco(f?.targetMeanPrice)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text('Fundamentos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final (rotulo, valor) in itens)
              Row(
                children: [
                  Expanded(child: Text(rotulo)),
                  const SizedBox(width: 8),
                  Text(valor, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Sinais extends StatelessWidget {
  const _Sinais({required this.fundamentos});

  final FundamentosAcao? fundamentos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sinais = derivarSinais(fundamentos);

    (Color, Color, IconData) estilo(TomSinal tom) => switch (tom) {
          TomSinal.positivo => (cs.tertiaryContainer, cs.onTertiaryContainer, Icons.trending_up),
          TomSinal.alerta => (cs.errorContainer, cs.onErrorContainer, Icons.warning_amber),
          TomSinal.neutro => (cs.surfaceContainerHighest, cs.onSurfaceVariant, Icons.info_outline),
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          'Sinais próprios (calculados localmente)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in sinais)
              () {
                final (bg, fg, icone) = estilo(s.tom);
                return Chip(
                  backgroundColor: bg,
                  avatar: Icon(icone, size: 18, color: fg),
                  label: Text(s.texto, style: TextStyle(color: fg)),
                );
              }(),
          ],
        ),
      ],
    );
  }
}
