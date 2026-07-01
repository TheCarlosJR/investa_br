import '../../../common/domain/enums/indexador.dart';

/// Snapshot dos indicadores anuais (decimais) usados como ENTRADA do motor de
/// cálculo. Ex.: `cdi: 0.1440` para 14,40% a.a. Fornecido pela camada `data`
/// (BCB SGS), já anualizado e parseado de `String` para `double`.
class Indicadores {
  const Indicadores({
    required this.cdi,
    required this.selic,
    required this.ipca,
    required this.igpm,
  });

  /// CDI anual efetivo (decimal).
  final double cdi;

  /// SELIC anual (decimal).
  final double selic;

  /// IPCA projetado anual (decimal).
  final double ipca;

  /// IGP-M projetado anual (decimal).
  final double igpm;

  /// Taxa anual do indexador (0 para prefixado).
  double anualDe(Indexador indexador) => switch (indexador) {
        Indexador.cdi => cdi,
        Indexador.selic => selic,
        Indexador.ipca => ipca,
        Indexador.igpm => igpm,
        Indexador.prefixado => 0,
      };

  @override
  bool operator ==(Object other) =>
      other is Indicadores &&
      other.cdi == cdi &&
      other.selic == selic &&
      other.ipca == ipca &&
      other.igpm == igpm;

  @override
  int get hashCode => Object.hash(cdi, selic, ipca, igpm);
}
