import '../../../common/domain/enums/indexador.dart';
import '../../../common/domain/tipo_rendimento.dart';

/// Descrição pt-BR legível da taxa contratada (ex.: `110,00% do CDI`,
/// `IPCA + 6,00%`, `13,00% a.a.`). Função pura.
String descreverTaxa(TipoRendimento tipo) => switch (tipo) {
      Prefixado(:final taxaAnual) => '${taxaAnual.formatar()} a.a.',
      Posfixado(:final indexador, :final percentualDoIndice) =>
        '${percentualDoIndice.formatar()} '
            'd${indexador == Indexador.selic ? 'a Selic' : 'o CDI'}',
      IndexadoMais(:final indexador, :final taxaReal) =>
        '${indexador.rotulo} + ${taxaReal.formatar()}',
      PercentualPuro(:final taxa) => '${taxa.formatar()} (taxa total)',
    };
