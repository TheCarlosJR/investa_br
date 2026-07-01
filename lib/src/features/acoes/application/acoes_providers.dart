import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers/core_providers.dart';
import '../data/posicoes_acoes_repository.dart';

final posicoesAcoesRepositoryProvider = Provider<PosicoesAcoesRepository>(
  (ref) => PosicoesAcoesRepository(ref.watch(databaseProvider)),
);
