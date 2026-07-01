import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/layout/root_shell.dart';
import '../features/acoes/domain/posicao_acao.dart';
import '../features/acoes/presentation/busca_acoes_screen.dart';
import '../features/acoes/presentation/cadastro_acao_screen.dart';
import '../features/acoes/presentation/detalhe_acao_screen.dart';
import '../features/configuracoes/presentation/configuracoes_screen.dart';
import '../features/conversor_taxas/presentation/conversor_screen.dart';
import '../features/patrimonio/presentation/dashboard_screen.dart';
import '../features/renda_fixa/domain/investimento_renda_fixa.dart';
import '../features/renda_fixa/presentation/cadastro_rf_screen.dart';
import '../features/renda_fixa/presentation/carteira_screen.dart';
import '../features/renda_fixa/presentation/detalhe_rf_screen.dart';

/// Chaves de navegador estáveis (evitam recriação do shell em rebuild).
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// `GoRouter` do app: um `StatefulShellRoute.indexedStack` com 5 branches (uma
/// por aba), preservando estado/pilha por branch. Telas de detalhe/cadastro são
/// `push` por cima do shell.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Início (Dashboard).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Branch 1 — Carteira (+ cadastro de RF empilhado).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/carteira',
                builder: (context, state) => const CarteiraScreen(),
                routes: [
                  GoRoute(
                    path: 'rf/novo',
                    builder: (context, state) => const CadastroRfScreen(),
                  ),
                  GoRoute(
                    path: 'rf/:id',
                    builder: (context, state) => DetalheRfScreen(
                      id: state.pathParameters['id']!,
                      inicial: state.extra as InvestimentoRendaFixa?,
                    ),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        builder: (context, state) => CadastroRfScreen(
                          inicial: state.extra as InvestimentoRendaFixa?,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'acao/novo',
                    builder: (context, state) => const CadastroAcaoScreen(),
                  ),
                  GoRoute(
                    path: 'acao/:id/editar',
                    builder: (context, state) => CadastroAcaoScreen(
                      inicial: state.extra as PosicaoAcao?,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Conversor.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conversor',
                builder: (context, state) => const ConversorScreen(),
              ),
            ],
          ),
          // Branch 3 — Ações.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/acoes',
                builder: (context, state) => const BuscaAcoesScreen(),
                routes: [
                  GoRoute(
                    path: ':ticker',
                    builder: (context, state) => DetalheAcaoScreen(
                      ticker: state.pathParameters['ticker']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 4 — Ajustes.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ajustes',
                builder: (context, state) => const ConfiguracoesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
