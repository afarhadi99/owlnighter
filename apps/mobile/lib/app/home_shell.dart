import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
// go_router provides BuildContext.go / .push used below.

/// Bottom-navigation shell wrapping the top-level tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (Routes.library, Icons.auto_stories_rounded, 'Library'),
    (Routes.streaks, Icons.local_fire_department_rounded, 'Streak'),
    (Routes.settings, Icons.settings_rounded, 'Settings'),
  ];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final i = _tabs.indexWhere((t) => loc.startsWith(t.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.$2), label: t.$3),
        ],
      ),
    );
  }
}
