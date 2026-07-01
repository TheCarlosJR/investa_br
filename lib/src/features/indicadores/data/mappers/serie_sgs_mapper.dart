/// Parse defensivo do `valor` do SGS. Aceita "14.50" e, defensivamente, "14,50".
double parseValorSgs(String raw) {
  final normalizado = raw.trim().replaceAll(',', '.');
  final v = double.tryParse(normalizado);
  if (v == null) throw FormatException('valor SGS inválido: "$raw"');
  return v;
}

/// Parse de data SGS no formato `dd/MM/yyyy`.
DateTime parseDataSgs(String raw) {
  final p = raw.trim().split('/');
  if (p.length != 3) throw FormatException('data SGS inválida: "$raw"');
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
}
