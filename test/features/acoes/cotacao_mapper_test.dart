import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/features/acoes/data/dto/cotacao_brapi_dto.dart';
import 'package:investa_br/src/features/acoes/data/mappers/cotacao_mapper.dart';

void main() {
  final agora = DateTime.utc(2026, 6, 18, 12);

  test('cotacaoFromDto mapeia preço, variação e fundamentos', () {
    const dto = CotacaoBrapiDto(
      symbol: 'PETR4',
      longName: 'Petrobras PN',
      regularMarketPrice: 38.54,
      regularMarketChangePercent: 1.33,
      priceEarnings: 4.62,
    );

    final c = cotacaoFromDto(dto, agora);
    expect(c.ticker, 'PETR4');
    expect(c.nomeEmpresa, 'Petrobras PN');
    expect(c.preco, Money.reais(38.54));
    expect(c.variacaoDiaPct.aPercentual, closeTo(1.33, 1e-9));
    expect(c.fundamentos?.precoLucro, 4.62);
  });

  test('sem fundamentos nem rating → fundamentos null (degrada)', () {
    const dto = CotacaoBrapiDto(
      symbol: 'PETR4',
      regularMarketPrice: 38.54,
      regularMarketChangePercent: 0,
    );
    final c = cotacaoFromDto(dto, agora);
    expect(c.fundamentos, isNull);
  });
}
