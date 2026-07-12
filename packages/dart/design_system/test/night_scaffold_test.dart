import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {required ThemeData theme}) => MaterialApp(
      theme: theme,
      home: home,
    );

void main() {
  group('NightScaffold', () {
    for (final entry in {
      'dark': AppTheme.dark(),
      'light': AppTheme.light(),
    }.entries) {
      testWidgets('renders under ${entry.key} theme without exceptions',
          (tester) async {
        await tester.pumpWidget(
          _app(
            const NightScaffold(
              title: 'Library',
              body: Center(child: Text('content')),
            ),
            theme: entry.value,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(NightScaffold), findsOneWidget);
        expect(find.text('Library'), findsOneWidget);
        expect(find.text('content'), findsOneWidget);
        // Sky is painted by default.
        expect(find.byType(NightSky), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'gives the Scaffold a real night900 background (not transparent)'
        ' and extends the body behind the app bar', (tester) async {
      await tester.pumpWidget(
        _app(
          const NightScaffold(body: SizedBox.shrink()),
          theme: AppTheme.dark(),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.night900);
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);

      expect(tester.takeException(), isNull);
    });

    testWidgets('showSky:false still keeps night900 + extend-behind (no band)',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const NightScaffold(showSky: false, body: SizedBox.shrink()),
          theme: AppTheme.dark(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NightSky), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.night900);
      expect(scaffold.extendBodyBehindAppBar, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('forwards actions and floatingActionButton', (tester) async {
      await tester.pumpWidget(
        _app(
          NightScaffold(
            title: 'Streaks',
            actions: const [Icon(Icons.settings)],
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
            body: const SizedBox.shrink(),
          ),
          theme: AppTheme.dark(),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
