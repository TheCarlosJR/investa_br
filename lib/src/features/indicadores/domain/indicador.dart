/// Tipo de indicador de mercado (mapeado para uma série do BCB SGS).
enum TipoIndicador {
  selicMeta, // SGS 432, % a.a.
  selicDiaria, // SGS 11, % ao dia
  cdiDiario, // SGS 12, % ao dia
  ipcaMensal, // SGS 433, % mês
  igpmMensal, // SGS 189, % mês
  tr, // SGS 226, % período (+ dataFim)
  poupanca; // SGS 195, % período (+ dataFim)

  int get serieSgs => switch (this) {
        TipoIndicador.selicMeta => 432,
        TipoIndicador.selicDiaria => 11,
        TipoIndicador.cdiDiario => 12,
        TipoIndicador.ipcaMensal => 433,
        TipoIndicador.igpmMensal => 189,
        TipoIndicador.tr => 226,
        TipoIndicador.poupanca => 195,
      };

  /// Séries cuja resposta inclui o campo `dataFim`.
  bool get temDataFim =>
      this == TipoIndicador.tr || this == TipoIndicador.poupanca;

  String get rotulo => switch (this) {
        TipoIndicador.selicMeta => 'SELIC (meta)',
        TipoIndicador.selicDiaria => 'SELIC (diária)',
        TipoIndicador.cdiDiario => 'CDI (diário)',
        TipoIndicador.ipcaMensal => 'IPCA (mês)',
        TipoIndicador.igpmMensal => 'IGP-M (mês)',
        TipoIndicador.tr => 'TR',
        TipoIndicador.poupanca => 'Poupança',
      };

  static TipoIndicador fromName(String name) => TipoIndicador.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TipoIndicador.selicMeta,
      );

  static TipoIndicador? fromSerie(int serie) {
    for (final t in TipoIndicador.values) {
      if (t.serieSgs == serie) return t;
    }
    return null;
  }
}

/// Valor de uma série SGS no cache diário. `valor` é o número cru do SGS
/// (ex.: `14.50` para SELIC meta % a.a.; `0.0534` para CDI % ao dia).
class Indicador {
  const Indicador({
    required this.tipo,
    required this.valor,
    required this.data,
    this.dataFim,
  });

  factory Indicador.fromJson(Map<String, Object?> json) => Indicador(
        tipo: TipoIndicador.fromName(json['tipo']! as String),
        valor: (json['valor']! as num).toDouble(),
        data: DateTime.parse(json['data']! as String),
        dataFim: json['dataFim'] == null
            ? null
            : DateTime.parse(json['dataFim']! as String),
      );

  final TipoIndicador tipo;
  final double valor;
  final DateTime data;
  final DateTime? dataFim;

  Map<String, Object?> toJson() => {
        'tipo': tipo.name,
        'valor': valor,
        'data': data.toIso8601String(),
        if (dataFim != null) 'dataFim': dataFim!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is Indicador &&
      other.tipo == tipo &&
      other.valor == valor &&
      other.data == data &&
      other.dataFim == dataFim;

  @override
  int get hashCode => Object.hash(tipo, valor, data, dataFim);
}
