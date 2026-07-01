import '../../../common/domain/money.dart';
import '../../../common/domain/percentual.dart';
import 'fundamentos_acao.dart';

/// Cotação de uma ação (brapi), preenchida sob demanda. Serializável para o
/// cache diário por ticker.
class Cotacao {
  const Cotacao({
    required this.ticker,
    required this.preco,
    required this.variacaoDiaPct,
    required this.atualizadoEm,
    this.nomeEmpresa,
    this.logoUrl,
    this.fundamentos,
  });

  factory Cotacao.fromJson(Map<String, Object?> json) => Cotacao(
        ticker: json['ticker']! as String,
        preco: Money.fromJson(json['preco']! as Map<String, Object?>),
        variacaoDiaPct:
            Percentual.fromJson(json['variacaoDiaPct']! as Map<String, Object?>),
        atualizadoEm: DateTime.parse(json['atualizadoEm']! as String),
        nomeEmpresa: json['nomeEmpresa'] as String?,
        logoUrl: json['logoUrl'] as String?,
        fundamentos: json['fundamentos'] == null
            ? null
            : FundamentosAcao.fromJson(
                json['fundamentos']! as Map<String, Object?>,
              ),
      );

  final String ticker;
  final Money preco;
  final Percentual variacaoDiaPct;
  final DateTime atualizadoEm;
  final String? nomeEmpresa;
  final String? logoUrl;

  /// Pode ser `null` (free) → a UI degrada.
  final FundamentosAcao? fundamentos;

  Map<String, Object?> toJson() => {
        'ticker': ticker,
        'preco': preco.toJson(),
        'variacaoDiaPct': variacaoDiaPct.toJson(),
        'atualizadoEm': atualizadoEm.toIso8601String(),
        if (nomeEmpresa != null) 'nomeEmpresa': nomeEmpresa,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (fundamentos != null) 'fundamentos': fundamentos!.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is Cotacao &&
      other.ticker == ticker &&
      other.preco == preco &&
      other.variacaoDiaPct == variacaoDiaPct &&
      other.atualizadoEm == atualizadoEm &&
      other.nomeEmpresa == nomeEmpresa &&
      other.logoUrl == logoUrl &&
      other.fundamentos == fundamentos;

  @override
  int get hashCode => Object.hash(
        ticker,
        preco,
        variacaoDiaPct,
        atualizadoEm,
        nomeEmpresa,
        logoUrl,
        fundamentos,
      );
}
