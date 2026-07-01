import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/configuracoes/application/config_providers.dart';
import 'features/configuracoes/domain/configuracao_tema.dart';
import 'routing/app_router.dart';

/// Raiz do aplicativo Investa BR.
///
/// F8: tema customizável — `ColorScheme.fromSeed` a partir da cor-semente
/// persistida, modo claro/escuro/sistema e Material You (`dynamic_color`) quando
/// disponível e habilitado. As preferências vêm de [configProvider] e
/// sobrevivem entre sessões.
class InvestaBrApp extends ConsumerWidget {
  const InvestaBrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final cfg = ref.watch(configProvider).valueOrNull ??
        ConfiguracaoTema(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme esquema(Brightness brilho, ColorScheme? dinamico) {
          if (cfg.useDynamic && dinamico != null) return dinamico.harmonized();
          return ColorScheme.fromSeed(
            seedColor: Color(cfg.seedArgb),
            brightness: brilho,
          );
        }

        ThemeData tema(Brightness brilho, ColorScheme? dinamico) => ThemeData(
              colorScheme: esquema(brilho, dinamico),
              useMaterial3: true,
            );

        return MaterialApp.router(
          title: 'Investa BR',
          debugShowCheckedModeBanner: false,
          themeMode: cfg.themeMode,
          theme: tema(Brightness.light, lightDynamic),
          darkTheme: tema(Brightness.dark, darkDynamic),
          routerConfig: router,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
        );
      },
    );
  }
}
