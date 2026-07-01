import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investa_br/src/features/conversor_taxas/presentation/conversor_screen.dart';
import 'package:investa_br/src/features/indicadores/application/indicadores_providers.dart';
import 'package:investa_br/src/features/indicadores/domain/indicadores.dart';

void main() {
  testWidgets('Conversor renderiza ranking e aviso CVM', (tester) async {
    // Superfície alta para a ListView construir todos os filhos (a seção de
    // ranking/aviso fica abaixo da dobra na viewport padrão).
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          indicadoresMotorProvider.overrideWithValue(
            const Indicadores(cdi: 0.144, selic: 0.144, ipca: 0.0472, igpm: 0.04),
          ),
        ],
        child: const MaterialApp(home: ConversorScreen()),
      ),
    );
    // Deixa o BarChart animar sem pumpAndSettle (animação contínua de gráfico).
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Conversor'), findsOneWidget);
    expect(find.textContaining('Ranking'), findsOneWidget);
    expect(find.textContaining('recomendação'), findsOneWidget); // aviso CVM
    expect(find.text('Adicionar opção'), findsOneWidget);
    // 4 opções padrão (um avatar por linha).
    expect(find.byType(CircleAvatar), findsNWidgets(4));
  });
}
