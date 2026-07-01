import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/common/domain/money.dart';
import 'package:investa_br/src/features/acoes/domain/posicao_acao.dart';

void main() {
  final pos = PosicaoAcao(
    id: 'a1',
    ticker: 'PETR4',
    quantidade: 100,
    precoMedio: Money.reais(38.42),
    dataCompra: DateTime(2026, 5, 2),
    corretora: 'XP',
    createdAt: DateTime(2026, 6, 17, 9),
    updatedAt: DateTime(2026, 6, 17, 9),
  );

  group('PosicaoAcao', () {
    test('round-trip JSON', () {
      expect(PosicaoAcao.fromJson(pos.toJson()), pos);
    });

    test('custoTotal = preço médio × quantidade', () {
      expect(pos.custoTotal, Money.reais(3842));
    });

    test('copyWith', () {
      final p = pos.copyWith(quantidade: 150);
      expect(p.quantidade, 150);
      expect(p.id, pos.id);
      expect(p.precoMedio, pos.precoMedio);
    });
  });
}
