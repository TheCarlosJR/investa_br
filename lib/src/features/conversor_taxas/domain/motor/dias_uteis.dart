/// Conta dias úteis no intervalo `[inicio, fim)` (exclui o dia final, convenção
/// de contagem de prazo). [feriados] = datas normalizadas (hora zero).
/// FUNÇÃO PURA: recebe os feriados, não busca em API.
int diasUteisEntre(DateTime inicio, DateTime fim, Set<DateTime> feriados) {
  final feriadosNorm = feriados.map(_soData).toSet();
  var dia = _soData(inicio);
  final ultimo = _soData(fim);
  var count = 0;
  while (dia.isBefore(ultimo)) {
    final ehFimDeSemana =
        dia.weekday == DateTime.saturday || dia.weekday == DateTime.sunday;
    if (!ehFimDeSemana && !feriadosNorm.contains(dia)) count++;
    dia = dia.add(const Duration(days: 1));
  }
  return count;
}

/// Dias corridos no intervalo `[inicio, fim)`.
int diasCorridosEntre(DateTime inicio, DateTime fim) =>
    _soData(fim).difference(_soData(inicio)).inDays;

DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);
