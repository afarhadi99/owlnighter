import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('StatCard', () {
    testWidgets('shows an uppercased label header and the value widget',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StatCard(
            label: 'Total XP',
            value: Text('120'),
          ),
        ),
      );
      expect(find.text('TOTAL XP'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('renders an optional header icon', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatCard(
            label: 'Streak',
            icon: Icons.local_fire_department_rounded,
            value: Text('3'),
          ),
        ),
      );
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });
  });
}
