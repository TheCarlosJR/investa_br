/// Erros tipados de backup. A UI faz pattern match e mostra mensagem pt-BR.
sealed class BackupError implements Exception {
  const BackupError(this.mensagem);
  final String mensagem;

  @override
  String toString() => 'BackupError: $mensagem';
}

class BackupInvalido extends BackupError {
  const BackupInvalido(super.mensagem);
}

class BackupCorrompido extends BackupError {
  const BackupCorrompido(super.mensagem);
}

class BackupVersaoMaisNova extends BackupError {
  BackupVersaoMaisNova(this.fileV, this.appV)
      : super(
          'Backup de versão mais nova ($fileV). '
          'Atualize o Investa BR (versão $appV).',
        );

  final int fileV;
  final int appV;
}

/// GATE de estrutura/tipos por documento. Lança [BackupInvalido] em campo
/// obrigatório ausente/tipo errado. NÃO valida id vazio (isso é tratado de
/// forma atômica na aplicação, garantindo rollback).
void validarEstrutura(Map<String, Object?> data) {
  final inv = data['investimentos_rf'];
  if (inv != null && inv is! List) {
    throw const BackupInvalido('Campo "investimentos_rf" deve ser uma lista.');
  }
  final acoes = data['posicoes_acoes'];
  if (acoes != null && acoes is! List) {
    throw const BackupInvalido('Campo "posicoes_acoes" deve ser uma lista.');
  }
  for (final raw in (inv as List?) ?? const []) {
    if (raw is! Map || raw['id'] is! String) {
      throw const BackupInvalido('Documento de renda fixa sem "id" válido.');
    }
  }
  for (final raw in (acoes as List?) ?? const []) {
    if (raw is! Map || raw['id'] is! String) {
      throw const BackupInvalido('Documento de ação sem "id" válido.');
    }
  }
}
