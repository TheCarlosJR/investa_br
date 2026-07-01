import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

/// Banco local aberto. NÃO tem default: o bootstrap (`main`) ou os testes devem
/// sobrescrever com `databaseProvider.overrideWithValue(db)`. Falhar cedo aqui
/// é melhor do que abrir um banco implícito no caminho errado.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError(
    'databaseProvider deve ser sobrescrito no bootstrap (ProviderScope).',
  ),
);

/// Relógio injetável. Toda lógica que precisa de "agora" (cache do dia,
/// marcação na curva) lê daqui, para tornar os testes determinísticos.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
