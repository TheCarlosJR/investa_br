/// Emissor de um título (opcional, enriquecido via CNPJ).
class Emissor {
  const Emissor({required this.cnpj, this.razaoSocial, this.nomeFantasia});

  /// Normaliza qualquer entrada de CNPJ para somente dígitos.
  factory Emissor.normalizado(String raw, {String? razaoSocial}) => Emissor(
        cnpj: raw.replaceAll(RegExp(r'\D'), ''),
        razaoSocial: razaoSocial,
      );

  factory Emissor.fromJson(Map<String, Object?> json) => Emissor(
        cnpj: json['cnpj']! as String,
        razaoSocial: json['razaoSocial'] as String?,
        nomeFantasia: json['nomeFantasia'] as String?,
      );

  final String cnpj;
  final String? razaoSocial;
  final String? nomeFantasia;

  Map<String, Object?> toJson() => {
        'cnpj': cnpj,
        if (razaoSocial != null) 'razaoSocial': razaoSocial,
        if (nomeFantasia != null) 'nomeFantasia': nomeFantasia,
      };

  @override
  bool operator ==(Object other) =>
      other is Emissor &&
      other.cnpj == cnpj &&
      other.razaoSocial == razaoSocial &&
      other.nomeFantasia == nomeFantasia;

  @override
  int get hashCode => Object.hash(cnpj, razaoSocial, nomeFantasia);
}
