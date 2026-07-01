/// Falha de domínio/dados (sealed). A UI faz pattern match e mostra mensagem
/// pt-BR adequada. Implementa [Exception] para poder ser propagada como erro de
/// um `AsyncValue`/`Future` (ex.: `AsyncValue.guard`).
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {this.retryAfter});
  final Duration? retryAfter;
}

class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Token ausente ou inválido']);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
