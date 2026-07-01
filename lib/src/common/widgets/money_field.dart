import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/money.dart';
import '../utils/parsers.dart';

/// Campo de valor em reais (prefixo `R$`). Reporta o valor parseado em reais
/// via [onChanged]; integra-se a um `Form` pelo [validator] (recebe reais ou
/// `null`). Não formata enquanto digita — deixa o usuário livre — e parseia
/// pt-BR no commit.
class MoneyField extends StatefulWidget {
  const MoneyField({
    required this.label,
    this.initial,
    this.onChanged,
    this.validator,
    super.key,
  });

  final String label;
  final Money? initial;
  final ValueChanged<double?>? onChanged;
  final String? Function(double? reais)? validator;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final inicial = widget.initial;
    _controller = TextEditingController(
      text: inicial == null || inicial.centavos == 0
          ? ''
          : inicial.reais.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: r'R$ ',
        border: const OutlineInputBorder(),
      ),
      onChanged: (s) => widget.onChanged?.call(parseNumeroPtBr(s)),
      validator: (s) => widget.validator?.call(parseNumeroPtBr(s ?? '')),
    );
  }
}
