import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/common/persistence/local_db.dart';
import 'src/common/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dados de locale pt-BR para DateFormat (datas, mês/ano).
  await initializeDateFormatting('pt_BR');

  // Abre o banco local antes de subir a árvore e injeta no ProviderScope.
  final localDb = LocalDb();
  final db = await localDb.open();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const InvestaBrApp(),
    ),
  );
}
