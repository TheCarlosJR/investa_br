import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_destinations.dart';

/// Shell responsivo das 5 abas. Três faixas de largura (Material 3 window size
/// classes), decididas por `MediaQuery.sizeOf(context).width`:
///
/// | Faixa    | Largura      | Componente                 |
/// |----------|--------------|----------------------------|
/// | compact  | `< 600dp`    | `NavigationBar` (rodapé)   |
/// | medium   | `600–839dp`  | `NavigationRail` compacto  |
/// | expanded | `>= 840dp`   | `NavigationRail(extended)` |
///
/// O `StatefulNavigationShell` preserva o estado/pilha de cada branch
/// (equivale ao `IndexedStack` exigido na decisão de arquitetura).
class RootShell extends StatelessWidget {
  const RootShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const double _bpMedium = 600;
  static const double _bpExpanded = 840;

  static const String _rotaNovoInvestimento = '/carteira/rf/novo';

  void _irParaBranch(int index) => navigationShell.goBranch(
        index,
        // re-toque na aba ativa volta à raiz do branch.
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final idx = navigationShell.currentIndex;
    const dests = AppDestinations.all;

    if (width < _bpMedium) {
      return Scaffold(
        body: navigationShell,
        floatingActionButton:
            AppDestinations.mostraFab(idx) ? _fabExtended(context) : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: _irParaBranch,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final d in dests)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= _bpExpanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: idx,
            onDestinationSelected: _irParaBranch,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            leading: _railLeading(context, idx, extended: extended),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _railLeading(BuildContext context, int idx, {required bool extended}) {
    if (!AppDestinations.mostraFab(idx)) return const SizedBox(height: 56);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: extended
          ? _fabExtended(context)
          : FloatingActionButton(
              tooltip: 'Novo investimento',
              onPressed: () => context.go(_rotaNovoInvestimento),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _fabExtended(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => context.go(_rotaNovoInvestimento),
        icon: const Icon(Icons.add),
        label: const Text('Investimento'),
      );
}
