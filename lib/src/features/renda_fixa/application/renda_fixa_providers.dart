import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers/core_providers.dart';
import '../data/renda_fixa_repository.dart';

final rendaFixaRepositoryProvider = Provider<RendaFixaRepository>(
  (ref) => RendaFixaRepository(ref.watch(databaseProvider)),
);
