import 'fundamentos_acao.dart';

/// Tom de um sinal (cor/ícone na UI; nunca só cor).
enum TomSinal { positivo, neutro, alerta }

/// Sinal informativo derivado LOCALMENTE de fundamentos. NUNCA é "recomendação
/// de analista" (CVM) — é um indicador calculado a partir de P/L, P/VP, DY, ROE.
class SinalAcao {
  const SinalAcao(this.texto, this.tom);
  final String texto;
  final TomSinal tom;

  @override
  bool operator ==(Object other) =>
      other is SinalAcao && other.texto == texto && other.tom == tom;

  @override
  int get hashCode => Object.hash(texto, tom);
}

/// Deriva sinais próprios a partir dos [fundamentos]. Degrada graciosamente:
/// ignora campos nulos e, se nada se aplica, devolve um sinal neutro. Sempre
/// inclui o aviso de ausência de rating de analista no plano gratuito.
List<SinalAcao> derivarSinais(FundamentosAcao? fundamentos) {
  final sinais = <SinalAcao>[];

  final pl = fundamentos?.precoLucro;
  if (pl != null) {
    if (pl <= 0) {
      sinais.add(const SinalAcao('P/L negativo — sem lucro no período', TomSinal.alerta));
    } else if (pl < 10) {
      sinais.add(SinalAcao('P/L baixo (${pl.toStringAsFixed(2)}) — pode estar atrativo', TomSinal.positivo));
    } else if (pl > 25) {
      sinais.add(SinalAcao('P/L alto (${pl.toStringAsFixed(2)}) — preço esticado', TomSinal.alerta));
    }
  }

  final pvp = fundamentos?.precoValorPatr;
  if (pvp != null && pvp > 0 && pvp < 1) {
    sinais.add(SinalAcao('P/VP ${pvp.toStringAsFixed(2)} — abaixo do valor patrimonial', TomSinal.positivo));
  }

  final dy = fundamentos?.dividendYield;
  if (dy != null && dy >= 0.06) {
    sinais.add(SinalAcao('Dividend yield alto (${(dy * 100).toStringAsFixed(1)}%)', TomSinal.positivo));
  }

  final roe = fundamentos?.roe;
  if (roe != null && roe >= 0.15) {
    sinais.add(SinalAcao('ROE alto (${(roe * 100).toStringAsFixed(1)}%) — boa rentabilidade', TomSinal.positivo));
  }

  if (sinais.isEmpty) {
    sinais.add(const SinalAcao('Sem fundamentos suficientes para sinais.', TomSinal.neutro));
  }

  if (fundamentos == null || !fundamentos.temRatingAnalista) {
    sinais.add(const SinalAcao('Sem dados de analistas no plano gratuito.', TomSinal.neutro));
  }

  return sinais;
}
