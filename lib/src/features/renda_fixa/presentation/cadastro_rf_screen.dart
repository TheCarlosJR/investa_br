import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common/domain/enums/base_dias.dart';
import '../../../common/domain/enums/classe_ativo.dart';
import '../../../common/domain/enums/tributacao.dart';
import '../../../common/domain/money.dart';
import '../../../common/providers/core_providers.dart';
import '../../../common/utils/formatters.dart';
import '../../../common/widgets/money_field.dart';
import '../../../common/widgets/percent_field.dart';
import '../../conversor_taxas/domain/motor/projetar.dart';
import '../../indicadores/application/indicadores_providers.dart';
import '../application/renda_fixa_list_provider.dart';
import '../domain/investimento_renda_fixa.dart';
import '../domain/taxa_contratada.dart';
import '../domain/tipo_rendimento_ui.dart';
import 'widgets/projecao_view.dart';

/// Cadastro/edição de renda fixa. Form único; modela a taxa como value object
/// (nunca um `double` solto) e mostra preview de projeção ao vivo (motor F1).
class CadastroRfScreen extends ConsumerStatefulWidget {
  const CadastroRfScreen({this.inicial, super.key});

  /// Quando presente, o form entra em modo edição (passado via `extra`).
  final InvestimentoRendaFixa? inicial;

  @override
  ConsumerState<CadastroRfScreen> createState() => _CadastroRfScreenState();
}

class _CadastroRfScreenState extends ConsumerState<CadastroRfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apelidoController = TextEditingController();
  final _taxaController = TextEditingController();

  late ClasseAtivo _classe;
  late TipoRendimentoUi _tipo;
  late BaseDias _baseDias;
  late DateTime _dataInicio;
  DateTime? _dataVencimento;
  double? _taxaPercent;
  double? _valorReais;

  bool get _editando => widget.inicial != null;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    final agora = ref.read(clockProvider)();

    _classe = inicial?.classe ?? ClasseAtivo.cdb;
    _baseDias = inicial?.taxa.baseDias ?? BaseDias.duteis252;
    _dataInicio = inicial?.dataInicio ?? DateTime(agora.year, agora.month, agora.day);
    _dataVencimento = inicial?.dataVencimento;
    _apelidoController.text = inicial?.apelido ?? '';
    _valorReais = inicial?.valorInicial.reais;

    final tipoInicial =
        TipoRendimentoUi.descrever(inicial?.taxa.tipoRendimento);
    _tipo = tipoInicial.$1;
    _taxaPercent = tipoInicial.$2;
    if (_taxaPercent != null) {
      _taxaController.text =
          _taxaPercent!.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _apelidoController.dispose();
    _taxaController.dispose();
    super.dispose();
  }

  InvestimentoRendaFixa? _rascunho() {
    if (_valorReais == null || _valorReais! <= 0 || _taxaPercent == null) {
      return null;
    }
    final agora = ref.read(clockProvider)();
    final base = widget.inicial;
    return InvestimentoRendaFixa(
      id: base?.id ?? const Uuid().v4(),
      classe: _classe,
      apelido: _apelidoController.text.trim().isEmpty
          ? _classe.rotulo
          : _apelidoController.text.trim(),
      valorInicial: Money.reais(_valorReais!),
      taxa: TaxaContratada(
        tipoRendimento: _tipo.montar(_taxaPercent!),
        baseDias: _baseDias,
      ),
      dataInicio: _dataInicio,
      dataVencimento: _dataVencimento,
      emissor: base?.emissor,
      observacoes: base?.observacoes,
      createdAt: base?.createdAt ?? agora,
      updatedAt: agora,
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final doc = _rascunho();
    if (doc == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await ref.read(rendaFixaListProvider.notifier).upsert(doc);
      messenger.showSnackBar(
        const SnackBar(content: Text('Investimento salvo.')),
      );
      if (router.canPop()) router.pop();
    } on Exception catch (_) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: errorColor,
          content: const Text('Não foi possível salvar. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _escolherData({required bool inicio}) async {
    final base = inicio ? _dataInicio : (_dataVencimento ?? _dataInicio);
    final escolhida = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _dataInicio = escolhida;
      } else {
        _dataVencimento = escolhida;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar investimento' : 'Novo investimento'),
        actions: [
          TextButton(onPressed: _salvar, child: const Text('Salvar')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _apelidoController,
              decoration: const InputDecoration(
                labelText: 'Apelido / Emissor',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ClasseAtivo>(
              initialValue: _classe,
              decoration: const InputDecoration(
                labelText: 'Classe do ativo',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in ClasseAtivo.values)
                  DropdownMenuItem(value: c, child: Text(c.rotulo)),
              ],
              onChanged: (c) => setState(() => _classe = c ?? _classe),
            ),
            const SizedBox(height: 16),
            Text('Tipo de rendimento',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in TipoRendimentoUi.values)
                  ChoiceChip(
                    label: Text(t.rotulo),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            PercentField(
              label: 'Taxa',
              suffix: _tipo.sufixo,
              controller: _taxaController,
              onChanged: (v) => setState(() => _taxaPercent = v),
              validator: (v) =>
                  v == null || v <= 0 ? 'Informe a taxa' : null,
            ),
            const SizedBox(height: 16),
            MoneyField(
              label: 'Valor inicial',
              initial: _valorReais == null ? null : Money.reais(_valorReais!),
              onChanged: (v) => setState(() => _valorReais = v),
              validator: (v) =>
                  v == null || v <= 0 ? 'Informe um valor maior que zero' : null,
            ),
            const SizedBox(height: 16),
            Text('Base de dias',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<BaseDias>(
              segments: const [
                ButtonSegment(value: BaseDias.duteis252, label: Text('252')),
                ButtonSegment(value: BaseDias.corridos360, label: Text('360')),
                ButtonSegment(value: BaseDias.corridos365, label: Text('365')),
              ],
              selected: {_baseDias},
              onSelectionChanged: (s) => setState(() => _baseDias = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CampoData(
                    rotulo: 'Início',
                    data: _dataInicio,
                    onTap: () => _escolherData(inicio: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoData(
                    rotulo: 'Vencimento',
                    data: _dataVencimento,
                    onTap: () => _escolherData(inicio: false),
                    onLimpar: _dataVencimento == null
                        ? null
                        : () => setState(() => _dataVencimento = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ChipIsencao(classe: _classe),
            const SizedBox(height: 24),
            _PreviewProjecao(rascunho: _rascunho()),
          ],
        ),
      ),
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({
    required this.rotulo,
    required this.data,
    required this.onTap,
    this.onLimpar,
  });

  final String rotulo;
  final DateTime? data;
  final VoidCallback onTap;
  final VoidCallback? onLimpar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          border: const OutlineInputBorder(),
          suffixIcon: onLimpar != null
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onLimpar)
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(data == null ? '—' : Formatters.data(data!)),
      ),
    );
  }
}

class _ChipIsencao extends StatelessWidget {
  const _ChipIsencao({required this.classe});

  final ClasseAtivo classe;

  @override
  Widget build(BuildContext context) {
    final isento = regraTributariaVigente2026.isento(classe);
    return Row(
      children: [
        Icon(
          isento ? Icons.verified_outlined : Icons.receipt_long_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isento
                ? 'Isento de IR (derivado da classe ${classe.rotulo}).'
                : 'Tributado por IR regressivo (derivado da classe).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _PreviewProjecao extends ConsumerWidget {
  const _PreviewProjecao({required this.rascunho});

  final InvestimentoRendaFixa? rascunho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final motor = ref.watch(indicadoresMotorProvider);
    final rf = rascunho;

    final Widget corpo;
    if (rf == null) {
      corpo = Text('Preencha taxa, valor e datas para ver a projeção.',
          style: textTheme.bodyMedium);
    } else if (motor == null) {
      corpo = Text(
        'Indicadores do dia indisponíveis — projeção aparece quando o '
        'snapshot carregar.',
        style: textTheme.bodyMedium,
      );
    } else {
      final resgate =
          rf.dataVencimento ?? DateTime(rf.dataInicio.year + 1, rf.dataInicio.month, rf.dataInicio.day);
      final proj = projetar(
        investimento: rf,
        indicadores: motor,
        dataResgate: resgate,
      );
      corpo = ProjecaoView(proj: proj, temVencimento: rf.dataVencimento != null);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projeção', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            corpo,
          ],
        ),
      ),
    );
  }
}
