/// Base URLs das APIs gratuitas (verificadas em 17/06/2026 — ver plano §7).
abstract final class ApiEndpoints {
  /// BCB SGS — `/bcdata.sgs.{codigo}/dados`.
  static const String sgsBase = 'https://api.bcb.gov.br/dados/serie';

  static const String brapiV1 = 'https://brapi.dev/api';
  static const String brapiV2 = 'https://brapi.dev/api/v2';

  static const String brasilApi = 'https://brasilapi.com.br/api';
  static const String openCnpj = 'https://api.opencnpj.org';
  static const String receitaWs = 'https://receitaws.com.br/v1';
  static const String awesomeApi = 'https://economia.awesomeapi.com.br';
}
