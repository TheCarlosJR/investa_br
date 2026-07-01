import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/charts/bar_comparador.dart';
import '../../../common/domain/money.dart';
import '../../../common/domain/percentual.dart';
import '../../../common/utils/parsers.dart';
import '../../../common/widgets/money_field.dart';
import '../../../common/widgets/percent_field.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../../indicadores/domain/indicadores.dart';
import '../../renda_fixa/domain/tipo_rendimento_ui.dart';
import '../domain/motor/comparador.dart';

/// Rascunho mutável de uma opção do comparador.
class _OpcaoDraft {
  _OpcaoDraft({required this.tipo, required this.isento, required double taxa})
      : taxaController = TextEditingController(
          text: taxa.toStringAsFixed(2).replaceAll('.', ','),
        );

  TipoRendimentoUi tipo;
  bool isento;
  final TextEditingController taxaController;

  double? get taxaPercent => parseNumeroPtBr(taxaController.text);
}

/// Conversor/Comparador: converte produtos heterogêneos para a métrica única
/// **rentabilidade líquida anual efetiva (base 252)** após IR/IOF, com gross-up
/// para isentos. Cálculo puro (motor F1) sobre os índices do dia (cache).
class ConversorScreen extends ConsumerStatefulWidget {
  const ConversorScreen({super.key});

  @override
  ConsumerState<ConversorScreen> createState() => _ConversorScreenState();
}

class _ConversorScreenState extends ConsumerState<ConversorScreen> {
  final _prazoController = TextEditingController(text: '720');
  double _valor = 10000;

  late final List<_OpcaoDraft> _opcoes = [
    _OpcaoDraft(tipo: TipoRendimentoUi.posCdi, isento: false, taxa: 110),
    _OpcaoDraft(tipo: TipoRendimentoUi.ipcaMais, isento: false, taxa: 6),
    _OpcaoDraft(tipo: TipoRendimentoUi.prefixado, isento: false, taxa: 13.5),
    _OpcaoDraft(tipo: TipoRendimentoUi.posCdi, isento: true, taxa: 95),
  ];

  int get _prazoDias => int.tryParse(_prazoController.text.trim()) ?? 0;

  @override
  void dispose() {
    _prazoController.dispose();
    for (final o in _opcoes) {
      o.taxaController.dispose();
    }
    super.dispose();
  }

  void _adicionar() => setState(
        () => _opcoes.add(
          _OpcaoDraft(tipo: TipoRendimentoUi.posCdi, isento: false, taxa: 100),
        ),
      );

  void _remover(int i) => setState(() {
        _opcoes.removeAt(i).taxaController.dispose();
      });

  List<ResultadoComparacao> _resultados(Indicadores indicadores) {
    final opcoes = <OpcaoComparacao>[];
    for (var i = 0; i < _opcoes.length; i++) {
      final d = _opcoes[i];
      final taxa = d.taxaPercent;
      if (taxa == null) continue;
      opcoes.add(
        OpcaoComparacao(
          rotulo: String.fromCharCode(65 + i), // A, B, C…
          tipo: d.tipo.montar(taxa),
          isento: d.isento,
        ),
      );
    }
    if (opcoes.isEmpty || _prazoDias <= 0 || _valor <= 0) return const [];
    return compararOpcoes(
      indicadores: indicadores,
      valor: _valor,
      prazoDias: _prazoDias,
      opcoes: opcoes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final motor = ref.watch(indicadoresMotorProvider);
    final indicadores =
        motor ?? const Indicadores(cdi: 0, selic: 0, ipca: 0, igpm: 0);
    final resultados = _resultados(indicadores);

    return Scaffold(
      appBar: AppBar(title: const Text('Conversor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: MoneyField(
                  label: 'Valor',
                  initial: Money.reais(_valor),
                  onChanged: (v) => setState(() => _valor = v ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _prazoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Prazo',
                    suffixText: 'dias',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IndicesDoDia(motor: motor),
          const Divider(height: 32),
          for (var i = 0; i < _opcoes.length; i++)
            _LinhaOpcao(
              rotulo: String.fromCharCode(65 + i),
              draft: _opcoes[i],
              onChanged: () => setState(() {}),
              onRemover: _opcoes.length > 1 ? () => _remover(i) : null,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _adicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar opção'),
            ),
          ),
          const Divider(height: 32),
          _Ranking(resultados: resultados),
          const SizedBox(height: 24),
          const _AvisoCvm(),
        ],
      ),
    );
  }
}

class _IndicesDoDia extends StatelessWidget {
  const _IndicesDoDia({required this.motor});

  final Indicadores? motor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (motor == null) {
      return Text(
        'Índices do dia indisponíveis — opções pós-fixadas e IPCA+ ficam '
        'zeradas até o snapshot carregar.',
        style: textTheme.bodySmall,
      );
    }
    final cdi = Percentual(fracao: motor!.cdi).formatar();
    final ipca = Percentual(fracao: motor!.ipca).formatar();
    return Text(
      'CDI anual: $cdi · IPCA proj. 12m: $ipca (do cache)',
      style: textTheme.bodySmall,
    );
  }
}

class _LinhaOpcao extends StatelessWidget {
  const _LinhaOpcao({
    required this.rotulo,
    required this.draft,
    required this.onChanged,
    this.onRemover,
  });

  final String rotulo;
  final _OpcaoDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemover;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text(rotulo)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TipoRendimentoUi>(
                    initialValue: draft.tipo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in TipoRendimentoUi.values)
                        DropdownMenuItem(value: t, child: Text(t.rotulo)),
                    ],
                    onChanged: (t) {
                      if (t != null) draft.tipo = t;
                      onChanged();
                    },
                  ),
                ),
                if (onRemover != null)
                  IconButton(
                    tooltip: 'Remover opção',
                    icon: const Icon(Icons.close),
                    onPressed: onRemover,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PercentField(
                    label: 'Taxa',
                    suffix: draft.tipo.sufixo,
                    controller: draft.taxaController,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Text('Isento'),
                    Switch(
                      value: draft.isento,
                      onChanged: (v) {
                        draft.isento = v;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking({required this.resultados});

  final List<ResultadoComparacao> resultados;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (resultados.isEmpty) {
      return Text(
        'Preencha valor, prazo e ao menos uma taxa para comparar.',
        style: textTheme.bodyMedium,
      );
    }

    final itens = [
      for (var i = 0; i < resultados.length; i++)
        BarComparadorItem(
          rotulo: resultados[i].rotulo,
          valorPercent: resultados[i].liquidoAnual * 100,
          valorFmt: Percentual(fracao: resultados[i].liquidoAnual).formatar(),
          melhor: i == 0,
        ),
    ];

    final isentos = resultados.where((r) => r.isento && r.grossUp != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ranking (líquido a.a., base 252)', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        BarComparador(itens: itens),
        if (isentos.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final r in isentos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${r.rotulo} (isento): líq '
                '${Percentual(fracao: r.liquidoAnual).formatar()} → um produto '
                'tributável precisaria render '
                '${Percentual(fracao: r.grossUp!).formatar()} bruto.',
                style: textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _AvisoCvm extends StatelessWidget {
  const _AvisoCvm();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Valores informativos, baseados em premissas de 2026. Não '
              'constituem recomendação de investimento (CVM).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
