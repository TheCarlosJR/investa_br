/// Parse defensivo de número digitado em pt-BR (vírgula decimal, ponto milhar).
/// Aceita `"10.000,50"`, `"10000,50"`, `"10.5"`, `"1.000"`. Retorna `null` se
/// não houver número válido.
///
/// Heurística para entradas só com ponto: múltiplos pontos ou último grupo com
/// 3 dígitos ⇒ separador de milhar (`"1.000"` → 1000); senão, decimal
/// (`"10.5"` → 10.5).
double? parseNumeroPtBr(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[^\d.,-]'), '');
  if (s.isEmpty || s == '-') return null;

  final temVirgula = s.contains(',');
  final temPonto = s.contains('.');

  if (temVirgula && temPonto) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (temVirgula) {
    s = s.replaceAll(',', '.');
  } else if (temPonto) {
    final partes = s.split('.');
    if (partes.length > 2 || partes.last.length == 3) {
      s = s.replaceAll('.', '');
    }
  }
  return double.tryParse(s);
}
