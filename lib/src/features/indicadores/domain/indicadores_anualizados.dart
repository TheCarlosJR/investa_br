import 'dart:math';

import 'indicador.dart';
import 'indicadores.dart';

/// Converte o snapshot CRU do SGS em [Indicadores] anualizados (decimais) — a
/// entrada que o motor de cálculo espera. FUNÇÃO PURA.
///
/// Regras de anualização (convenções do mercado brasileiro):
/// - SELIC meta (série 432) já vem **% a.a.** → só divide por 100.
/// - CDI diário (série 12) vem **% ao dia** → compõe em 252 dias úteis.
/// - IPCA/IGP-M (séries 433/189) vêm **% ao mês** → compõe em 12 meses.
///
/// Indicadores ausentes no snapshot entram como `0` (degradação graciosa).
Indicadores anualizarIndicadores(List<Indicador> snapshot) {
  double? valorDe(TipoIndicador tipo) {
    for (final i in snapshot) {
      if (i.tipo == tipo) return i.valor;
    }
    return null;
  }

  final selicAnual = (valorDe(TipoIndicador.selicMeta) ?? 0) / 100;

  final cdiDia = (valorDe(TipoIndicador.cdiDiario) ?? 0) / 100;
  final cdiAnual = cdiDia == 0 ? 0.0 : pow(1 + cdiDia, 252).toDouble() - 1;

  final ipcaMes = (valorDe(TipoIndicador.ipcaMensal) ?? 0) / 100;
  final ipcaAnual = ipcaMes == 0 ? 0.0 : pow(1 + ipcaMes, 12).toDouble() - 1;

  final igpmMes = (valorDe(TipoIndicador.igpmMensal) ?? 0) / 100;
  final igpmAnual = igpmMes == 0 ? 0.0 : pow(1 + igpmMes, 12).toDouble() - 1;

  return Indicadores(
    cdi: cdiAnual,
    selic: selicAnual,
    ipca: ipcaAnual,
    igpm: igpmAnual,
  );
}
