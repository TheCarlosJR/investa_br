import 'package:intl/intl.dart';

/// Formatação pt-BR centralizada. NUNCA formatar números/datas à mão fora daqui
/// (nem na UI). Valores monetários e percentuais como value object usam
/// `Money.formatar` / `Percentual.formatar`; aqui ficam datas e os números
/// "crus" do SGS (que já vêm em unidade de %).
abstract final class Formatters {
  static const String _locale = 'pt_BR';

  static final DateFormat _data = DateFormat('dd/MM/yyyy', _locale);
  static final DateFormat _dataHora = DateFormat('dd/MM/yyyy HH:mm', _locale);
  static final DateFormat _mesAno = DateFormat('MMM/yyyy', _locale);

  /// `17/06/2026`.
  static String data(DateTime d) => _data.format(d.toLocal());

  /// `17/06/2026 08:55`.
  static String dataHora(DateTime d) => _dataHora.format(d.toLocal());

  /// `jun/2026` (referência mensal de IPCA/IGP-M).
  static String mesAno(DateTime d) => _mesAno.format(d.toLocal());

  /// Número que JÁ está em escala de % (ex.: SGS `14.50` → `14,50%`).
  /// [casas] controla as decimais (CDI diário precisa de 4).
  static String percentBruto(double valorEmPercent, {int casas = 2}) {
    final nf = NumberFormat.decimalPattern(_locale)
      ..minimumFractionDigits = casas
      ..maximumFractionDigits = casas;
    return '${nf.format(valorEmPercent)}%';
  }
}
