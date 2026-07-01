import '../../../common/domain/enums/classe_ativo.dart';
import '../../../common/domain/money.dart';

/// Agrupamento de exibição da carteira (donut + legenda da Home).
enum GrupoAtivo {
  rendaFixa,
  tesouroDireto,
  acoes;

  String get rotulo => switch (this) {
        GrupoAtivo.rendaFixa => 'Renda Fixa',
        GrupoAtivo.tesouroDireto => 'Tesouro Direto',
        GrupoAtivo.acoes => 'Ações',
      };

  /// Classes de Tesouro Direto vão para o grupo próprio; o restante de RF é
  /// "Renda Fixa".
  static GrupoAtivo deRendaFixa(ClasseAtivo classe) => switch (classe) {
        ClasseAtivo.tesouroSelic ||
        ClasseAtivo.tesouroPrefixado ||
        ClasseAtivo.tesouroIpca =>
          GrupoAtivo.tesouroDireto,
        _ => GrupoAtivo.rendaFixa,
      };
}

/// Fatia agregada por [GrupoAtivo], com valor atual (marcado a hoje).
class FatiaPatrimonio {
  const FatiaPatrimonio({required this.grupo, required this.valorAtual});

  final GrupoAtivo grupo;
  final Money valorAtual;

  @override
  bool operator ==(Object other) =>
      other is FatiaPatrimonio &&
      other.grupo == grupo &&
      other.valorAtual == valorAtual;

  @override
  int get hashCode => Object.hash(grupo, valorAtual);
}

/// Patrimônio consolidado: total atual (bruto), total investido (custo) e a
/// distribuição por grupo. NÃO recalcula finanças em si — recebe pronto do
/// provider, que usa o motor (RF marcada na curva, ações pela cotação/custo).
class Patrimonio {
  const Patrimonio({
    required this.totalAtual,
    required this.totalInvestido,
    required this.fatias,
  });

  static const Patrimonio vazio = Patrimonio(
    totalAtual: Money.zero,
    totalInvestido: Money.zero,
    fatias: [],
  );

  final Money totalAtual;
  final Money totalInvestido;

  /// Fatias com `valorAtual > 0`, da maior para a menor.
  final List<FatiaPatrimonio> fatias;

  bool get estaVazio => fatias.isEmpty;

  /// Rendimento bruto acumulado (atual − investido).
  Money get rendimento => totalAtual - totalInvestido;

  /// Fração de rendimento sobre o investido (0.12 = +12%). `0` se sem custo.
  double get rendimentoFracao =>
      totalInvestido.centavos == 0 ? 0 : rendimento.centavos / totalInvestido.centavos;

  /// Fração que a [fatia] representa do total atual.
  double fracaoDe(FatiaPatrimonio fatia) =>
      totalAtual.centavos == 0 ? 0 : fatia.valorAtual.centavos / totalAtual.centavos;
}
