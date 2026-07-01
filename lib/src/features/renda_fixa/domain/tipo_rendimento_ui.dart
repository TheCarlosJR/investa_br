import '../../../common/domain/enums/indexador.dart';
import '../../../common/domain/percentual.dart';
import '../../../common/domain/tipo_rendimento.dart';

/// Opções de tipo de rendimento na UI (cada uma já fixa o indexador). Centraliza
/// o mapeamento UI ↔ [TipoRendimento] reutilizado pelo cadastro de RF e pelo
/// conversor — a taxa é digitada em pontos percentuais (`110`, `13,5`).
enum TipoRendimentoUi {
  prefixado('Prefixado', '% a.a.'),
  posCdi('Pós-CDI', '% do CDI'),
  posSelic('Pós-Selic', '% da Selic'),
  ipcaMais('IPCA+', '% a.a.'),
  igpmMais('IGP-M+', '% a.a.'),
  percentualPuro('% puro', '% a.a.');

  const TipoRendimentoUi(this.rotulo, this.sufixo);

  final String rotulo;
  final String sufixo;

  /// Monta o value object a partir da taxa em pontos percentuais.
  TipoRendimento montar(double taxaPercent) {
    final frac = Percentual.percentual(taxaPercent);
    return switch (this) {
      TipoRendimentoUi.prefixado => Prefixado(taxaAnual: frac),
      TipoRendimentoUi.posCdi =>
        Posfixado(indexador: Indexador.cdi, percentualDoIndice: frac),
      TipoRendimentoUi.posSelic =>
        Posfixado(indexador: Indexador.selic, percentualDoIndice: frac),
      TipoRendimentoUi.ipcaMais =>
        IndexadoMais(indexador: Indexador.ipca, taxaReal: frac),
      TipoRendimentoUi.igpmMais =>
        IndexadoMais(indexador: Indexador.igpm, taxaReal: frac),
      TipoRendimentoUi.percentualPuro => PercentualPuro(taxa: frac),
    };
  }

  /// Reverso (prefill de edição): deriva a opção de UI e a taxa em pontos
  /// percentuais de um [TipoRendimento] existente.
  static (TipoRendimentoUi, double?) descrever(TipoRendimento? tipo) =>
      switch (tipo) {
        Prefixado(:final taxaAnual) => (
            TipoRendimentoUi.prefixado,
            taxaAnual.aPercentual,
          ),
        Posfixado(:final indexador, :final percentualDoIndice) => (
            indexador == Indexador.selic
                ? TipoRendimentoUi.posSelic
                : TipoRendimentoUi.posCdi,
            percentualDoIndice.aPercentual,
          ),
        IndexadoMais(:final indexador, :final taxaReal) => (
            indexador == Indexador.igpm
                ? TipoRendimentoUi.igpmMais
                : TipoRendimentoUi.ipcaMais,
            taxaReal.aPercentual,
          ),
        PercentualPuro(:final taxa) => (
            TipoRendimentoUi.percentualPuro,
            taxa.aPercentual,
          ),
        null => (TipoRendimentoUi.posCdi, null),
      };
}
