import '../../../../common/cache/cache_snapshot.dart';
import '../../../../common/result/result.dart';
import '../indicador.dart';

// Interface de repositório (limite arquitetural para DI/teste), não um
// callback de um método só.
// ignore: one_member_abstracts
abstract interface class IndicadoresRepository {
  /// Lê do cache do dia; se ausente/expirado, busca remoto e persiste.
  /// [forcarRefresh] ignora o cache (botão de refresh manual). Em erro de rede,
  /// faz fallback para o último cache existente marcado `stale`.
  Future<Result<CacheSnapshot<List<Indicador>>>> obterIndicadores({
    bool forcarRefresh = false,
  });
}
