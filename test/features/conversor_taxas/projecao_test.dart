import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/base_dias.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/features/conversor_taxas/domain/motor/projetar.dart';
import 'package:investa_br/src/features/indicadores/domain/indicadores.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';

void main() {
  const idx = Indicadores(cdi: 0.10, selic: 0.105, ipca: 0.04, igpm: 0.05);
  final inicio = DateTime(2025, 1, 2);
  final umAno = DateTime(2026, 1, 2);

  InvestimentoRendaFixa inv(ClasseAtivo classe) => InvestimentoRendaFixa(
        id: 'x',
        classe: classe,
        apelido: 'teste',
        valorInicial: Money.reais(1000),
        taxa: TaxaContratada(
          tipoRendimento: Prefixado(taxaAnual: Percentual.percentual(10)),
          baseDias: BaseDias.corridos365,
        ),
        dataInicio: inicio,
        createdAt: inicio,
        updatedAt: inicio,
      );

  test('CDB prefixado 10% por 1 ano (base 365): IR 17,5%', () {
    final p = projetar(
      investimento: inv(ClasseAtivo.cdb),
      indicadores: idx,
      dataResgate: umAno,
    );
    expect(p.diasCorridos, 365);
    expect(p.valorBruto, Money.reais(1100));
    expect(p.rendimentoBruto, Money.reais(100));
    expect(p.iof, Money.zero);
    expect(p.ir, Money.reais(17.5));
    expect(p.valorLiquido, Money.reais(1082.5));
    expect(p.taxaBrutaEquivalente, isNull);
  });

  test('LCI isenta: IR zero, líquido == bruto e gross-up presente', () {
    final p = projetar(
      investimento: inv(ClasseAtivo.lci),
      indicadores: idx,
      dataResgate: umAno,
    );
    expect(p.ir, Money.zero);
    expect(p.valorLiquido, p.valorBruto);
    expect(p.taxaBrutaEquivalente, isNotNull);
  });

  test('CDB com resgate < 30 dias tem IOF positivo', () {
    final p = projetar(
      investimento: inv(ClasseAtivo.cdb),
      indicadores: idx,
      dataResgate: DateTime(2025, 1, 15),
    );
    expect(p.diasCorridos, 13);
    expect(p.iof.isPositivo, isTrue);
    expect(p.valorLiquido.centavos, lessThan(p.valorBruto.centavos));
  });

  test('resgate <= início retorna projeção neutra', () {
    final p = projetar(
      investimento: inv(ClasseAtivo.cdb),
      indicadores: idx,
      dataResgate: inicio,
    );
    expect(p.rendimentoBruto, Money.zero);
    expect(p.valorLiquido, Money.reais(1000));
  });
}
