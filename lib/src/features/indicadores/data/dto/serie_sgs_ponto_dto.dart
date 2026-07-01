/// Ponto cru de uma série do BCB SGS. `valor` chega como STRING ("14.50" /
/// "0.053400"); `dataFim` só vem nas séries 226 (TR) e 195 (poupança).
class SerieSgsPontoDto {
  const SerieSgsPontoDto({
    required this.data,
    required this.valor,
    this.dataFim,
  });

  factory SerieSgsPontoDto.fromJson(Map<String, dynamic> json) =>
      SerieSgsPontoDto(
        data: json['data'] as String,
        valor: json['valor'] as String,
        dataFim: json['dataFim'] as String?,
      );

  final String data; // dd/MM/yyyy
  final String? dataFim;
  final String valor;
}
