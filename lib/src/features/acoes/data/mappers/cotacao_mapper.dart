import '../../../../common/domain/money.dart';
import '../../../../common/domain/percentual.dart';
import '../../domain/cotacao.dart';
import '../../domain/fundamentos_acao.dart';
import '../dto/cotacao_brapi_dto.dart';

/// Converte o DTO da brapi em [Cotacao] de domínio. [agora] é injetado para
/// tornar o mapeamento determinístico. Função pura.
Cotacao cotacaoFromDto(CotacaoBrapiDto dto, DateTime agora) {
  final fundamentos = FundamentosAcao(
    precoLucro: dto.priceEarnings,
    precoValorPatr: dto.priceToBook,
    dividendYield: dto.dividendYield,
    roe: dto.returnOnEquity,
    recommendationKey: dto.recommendationKey,
    targetMeanPrice: dto.targetMeanPrice,
    numberOfAnalystOpinions: dto.numberOfAnalystOpinions,
  );
  return Cotacao(
    ticker: dto.symbol,
    preco: Money.reais(dto.regularMarketPrice ?? 0),
    variacaoDiaPct: Percentual.percentual(dto.regularMarketChangePercent ?? 0),
    atualizadoEm: agora,
    nomeEmpresa: dto.longName ?? dto.shortName,
    logoUrl: dto.logourl,
    fundamentos: fundamentos.vazio && !fundamentos.temRatingAnalista
        ? null
        : fundamentos,
  );
}
