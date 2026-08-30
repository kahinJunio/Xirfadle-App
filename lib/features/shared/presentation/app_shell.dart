import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-navigation scaffold shared by both modes; the destination set
/// differs per role.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        // `initialLocation: true` re-taps back to the branch root.
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

const customerDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.receipt_long_outlined),
    selectedIcon: Icon(Icons.receipt_long_rounded),
    label: 'My requests',
  ),
];

const providerDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.dashboard_outlined),
    selectedIcon: Icon(Icons.dashboard_rounded),
    label: 'Dashboard',
  ),
  NavigationDestination(
    icon: Icon(Icons.inbox_outlined),
    selectedIcon: Icon(Icons.inbox_rounded),
    label: 'Dispatches',
  ),
  NavigationDestination(
    icon: Icon(Icons.handyman_outlined),
    selectedIcon: Icon(Icons.handyman_rounded),
    label: 'Active job',
  ),
];
