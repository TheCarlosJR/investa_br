import 'package:flutter/material.dart';

/// Um destino de navegação do shell. Fonte ÚNICA (DRY) consumida tanto pelo
/// `NavigationBar` quanto pelo `NavigationRail`, evitando divergência de
/// ícones/labels/rotas entre os layouts.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.location,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Rota raiz do branch (usada para deep-link/restauração).
  final String location;
}

abstract final class AppDestinations {
  static const inicio = AppDestination(
    label: 'Início',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    location: '/',
  );
  static const carteira = AppDestination(
    label: 'Carteira',
    icon: Icons.pie_chart_outline,
    selectedIcon: Icons.pie_chart,
    location: '/carteira',
  );
  static const conversor = AppDestination(
    label: 'Conversor',
    icon: Icons.swap_horiz_outlined,
    selectedIcon: Icons.swap_horiz,
    location: '/conversor',
  );
  static const acoes = AppDestination(
    label: 'Ações',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    location: '/acoes',
  );
  static const ajustes = AppDestination(
    label: 'Ajustes',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    location: '/ajustes',
  );

  static const List<AppDestination> all = [
    inicio,
    carteira,
    conversor,
    acoes,
    ajustes,
  ];

  /// O FAB "+ Investimento" aparece só em Início (0) e Carteira (1).
  static bool mostraFab(int index) => index == 0 || index == 1;
}
