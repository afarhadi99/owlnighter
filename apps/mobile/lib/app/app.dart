import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme/theme_re_exports.dart';
import 'router.dart';

/// Root application widget. Wires the theme and the go_router-based navigation.
class OwlnighterApp extends ConsumerWidget {
  const OwlnighterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'owlnighter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Night-reading app → default to dark; respect OS preference otherwise.
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
