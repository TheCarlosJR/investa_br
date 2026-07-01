import '../../../../common/domain/money.dart';
import '../../../indicadores/domain/indicadores.dart';
import '../../../renda_fixa/domain/investimento_renda_fixa.dart';
import 'projetar.dart';

/// Valor bruto ATUAL de uma renda fixa, marcada na curva da taxa contratada até
/// [hoje]. Sem [motor] (snapshot de indicadores ainda não carregado), degrada
/// para o valor inicial. Função pura.
Money valorAtualRendaFixa(
  InvestimentoRendaFixa rf,
  Indicadores? motor,
  DateTime hoje,
) {
  if (motor == null) return rf.valorInicial;
  return projetar(
    investimento: rf,
    indicadores: motor,
    dataResgate: hoje,
  ).valorBruto;
}
