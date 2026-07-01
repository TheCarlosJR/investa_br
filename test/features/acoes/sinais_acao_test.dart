import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/acoes/domain/fundamentos_acao.dart';
import 'package:investa_br/src/features/acoes/domain/sinais_acao.dart';

void main() {
  group('derivarSinais', () {
    test('P/L baixo gera sinal positivo', () {
      final s = derivarSinais(const FundamentosAcao(precoLucro: 4.62));
      expect(s.any((e) => e.tom == TomSinal.positivo && e.texto.contains('P/L baixo')), isTrue);
    });

    test('P/L negativo gera alerta', () {
      final s = derivarSinais(const FundamentosAcao(precoLucro: -3));
      expect(s.any((e) => e.tom == TomSinal.alerta), isTrue);
    });

    test('sempre avisa ausência de rating no plano gratuito', () {
      final s = derivarSinais(const FundamentosAcao(precoLucro: 8));
      expect(s.any((e) => e.texto.contains('Sem dados de analistas')), isTrue);
    });

    test('com rating de analista, não mostra o aviso de ausência', () {
      final s = derivarSinais(
        const FundamentosAcao(precoLucro: 8, recommendationKey: 'buy'),
      );
      expect(s.any((e) => e.texto.contains('Sem dados de analistas')), isFalse);
    });

    test('fundamentos nulos → sinal neutro + aviso', () {
      final s = derivarSinais(null);
      expect(s, isNotEmpty);
      expect(s.every((e) => e.tom == TomSinal.neutro), isTrue);
    });
  });
}
