import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/parsers.dart';

/// Campo de taxa percentual. Reporta o número EM PONTOS PERCENTUAIS (ex.: `110`
/// para 110% do CDI, `13,5` para 13,5% a.a.) — quem consome converte para
/// fração via `Percentual.percentual(...)`. O [suffix] muda conforme o tipo de
/// rendimento (`% do CDI`, `% a.a.`, `IPCA + __% a.a.` …).
class PercentField extends StatelessWidget {
  const PercentField({
    required this.label,
    required this.suffix,
    this.controller,
    this.onChanged,
    this.validator,
    super.key,
  });

  final String label;
  final String suffix;
  final TextEditingController? controller;
  final ValueChanged<double?>? onChanged;
  final String? Function(double? percent)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (s) => onChanged?.call(parseNumeroPtBr(s)),
      validator: (s) => validator?.call(parseNumeroPtBr(s ?? '')),
    );
  }
}
