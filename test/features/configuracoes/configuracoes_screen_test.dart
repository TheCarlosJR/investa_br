import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:investa_br/src/common/cache/cache_snapshot.dart';
import 'package:investa_br/src/common/result/result.dart';
import 'package:investa_br/src/features/configuracoes/application/config_providers.dart';
import 'package:investa_br/src/features/configuracoes/domain/configuracao_tema.dart';
import 'package:investa_br/src/features/configuracoes/presentation/configuracoes_screen.dart';
import 'package:investa_br/src/features/indicadores/application/indicadores_providers.dart';
import 'package:investa_br/src/features/indicadores/domain/indicador.dart';
import 'package:investa_br/src/features/indicadores/domain/repositories/indicadores_repository.dart';

/// Config em memória (sem sembast → sem timers pendentes no widget test).
class _FakeConfig extends ConfiguracaoNotifier {
  @override
  Future<ConfiguracaoTema> build() async =>
      ConfiguracaoTema(updatedAt: DateTime.utc(2026, 6, 18));
}

class _FakeIndicadoresRepository implements IndicadoresRepository {
  @override
  Future<Result<CacheSnapshot<List<Indicador>>>> obterIndicadores({
    bool forcarRefresh = false,
  }) async =>
      Success(
        CacheSnapshot<List<Indicador>>(
          dados: const [],
          dataUltimaAtualizacao: '2026-06-18',
          fetchedAt: DateTime.utc(2026, 6, 18, 8, 55),
        ),
      );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Ajustes renderiza as seções Aparência, Dados e Sobre',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWith(_FakeConfig.new),
          indicadoresRepositoryProvider
              .overrideWithValue(_FakeIndicadoresRepository()),
        ],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Dados'), findsOneWidget);
    expect(find.text('Sobre'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
  });
}
