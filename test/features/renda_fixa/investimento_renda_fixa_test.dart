import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/enums/classe_ativo.dart';
import 'package:investa_br/src/common/domain/enums/indexador.dart';
import 'package:investa_br/src/common/domain/enums/tributacao.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/common/domain/percentual.dart';
import 'package:investa_br/src/common/domain/tipo_rendimento.dart';
import 'package:investa_br/src/features/renda_fixa/domain/emissor.dart';
import 'package:investa_br/src/features/renda_fixa/domain/investimento_renda_fixa.dart';
import 'package:investa_br/src/features/renda_fixa/domain/taxa_contratada.dart';

void main() {
  final investimento = InvestimentoRendaFixa(
    id: '8f3c1e2a-uuid',
    classe: ClasseAtivo.cdb,
    apelido: 'CDB Banco X 2027',
    valorInicial: Money.reais(10000),
    taxa: const TaxaContratada(
      tipoRendimento: Posfixado(
        indexador: Indexador.cdi,
        percentualDoIndice: Percentual(fracao: 1.10),
      ),
    ),
    dataInicio: DateTime(2026, 1, 10),
    dataVencimento: DateTime(2027, 1, 10),
    emissor: Emissor.normalizado('00.000.000/0001-91', razaoSocial: 'BANCO X SA'),
    createdAt: DateTime(2026, 6, 17, 9),
    updatedAt: DateTime(2026, 6, 17, 9),
  );

  group('InvestimentoRendaFixa', () {
    test('round-trip JSON preserva a entidade', () {
      expect(
        InvestimentoRendaFixa.fromJson(investimento.toJson()),
        investimento,
      );
    });

    test('Emissor.normalizado mantém só dígitos do CNPJ', () {
      expect(investimento.emissor!.cnpj, '00000000000191');
    });

    test('isento/tributacao derivam da regra vigente', () {
      expect(investimento.isento(regraTributariaVigente2026), isFalse);
      expect(
        investimento.tributacao(regraTributariaVigente2026),
        Tributacao.irRegressivo,
      );
    });

    test('vigenteEm respeita o intervalo', () {
      expect(investimento.vigenteEm(DateTime(2026, 6)), isTrue);
      expect(investimento.vigenteEm(DateTime(2025, 12)), isFalse);
      expect(investimento.vigenteEm(DateTime(2027, 6)), isFalse);
    });

    test('copyWith altera apenas o campo informado', () {
      final alterado = investimento.copyWith(apelido: 'Novo nome');
      expect(alterado.apelido, 'Novo nome');
      expect(alterado.id, investimento.id);
      expect(alterado.valorInicial, investimento.valorInicial);
    });
  });
}
