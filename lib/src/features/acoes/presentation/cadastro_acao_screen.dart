import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common/domain/money.dart';
import '../../../common/providers/core_providers.dart';
import '../../../common/utils/formatters.dart';
import '../../../common/widgets/money_field.dart';
import '../application/acoes_list_provider.dart';
import '../domain/posicao_acao.dart';

/// Cadastro/edição de posição em ação. A cotação ao vivo e o P/L chegam na
/// Fase 7 (datasource brapi); aqui registramos ticker, quantidade, preço médio,
/// corretora e data da compra.
class CadastroAcaoScreen extends ConsumerStatefulWidget {
  const CadastroAcaoScreen({this.inicial, super.key});

  final PosicaoAcao? inicial;

  @override
  ConsumerState<CadastroAcaoScreen> createState() => _CadastroAcaoScreenState();
}

class _CadastroAcaoScreenState extends ConsumerState<CadastroAcaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _qtdController = TextEditingController();
  final _corretoraController = TextEditingController();

  late DateTime _dataCompra;
  double? _precoReais;

  bool get _editando => widget.inicial != null;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    final agora = ref.read(clockProvider)();
    _dataCompra = inicial?.dataCompra ?? DateTime(agora.year, agora.month, agora.day);
    _tickerController.text = inicial?.ticker ?? '';
    _qtdController.text = inicial?.quantidade.toString() ?? '';
    _corretoraController.text = inicial?.corretora ?? '';
    _precoReais = inicial?.precoMedio.reais;
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _qtdController.dispose();
    _corretoraController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final agora = ref.read(clockProvider)();
    final base = widget.inicial;
    final corretora = _corretoraController.text.trim();

    final posicao = PosicaoAcao(
      id: base?.id ?? const Uuid().v4(),
      ticker: _tickerController.text.trim().toUpperCase(),
      quantidade: int.parse(_qtdController.text.trim()),
      precoMedio: Money.reais(_precoReais!),
      dataCompra: _dataCompra,
      corretora: corretora.isEmpty ? null : corretora,
      createdAt: base?.createdAt ?? agora,
      updatedAt: agora,
    );

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await ref.read(acoesListProvider.notifier).upsert(posicao);
      messenger.showSnackBar(const SnackBar(content: Text('Posição salva.')));
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

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataCompra,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _dataCompra = escolhida);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar posição' : 'Nova posição — Ações'),
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
              controller: _tickerController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Ativo (ticker)',
                hintText: 'PETR4',
                border: OutlineInputBorder(),
              ),
              validator: (s) =>
                  (s == null || s.trim().isEmpty) ? 'Informe o ticker' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                border: OutlineInputBorder(),
              ),
              validator: (s) {
                final q = int.tryParse((s ?? '').trim());
                return q == null || q <= 0 ? 'Quantidade inválida' : null;
              },
            ),
            const SizedBox(height: 16),
            MoneyField(
              label: 'Preço médio',
              initial: _precoReais == null ? null : Money.reais(_precoReais!),
              onChanged: (v) => _precoReais = v,
              validator: (v) =>
                  v == null || v <= 0 ? 'Informe o preço médio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _corretoraController,
              decoration: const InputDecoration(
                labelText: 'Corretora (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _escolherData,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da compra',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(Formatters.data(_dataCompra)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cotação ao vivo e P/L chegam na Fase 7.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
