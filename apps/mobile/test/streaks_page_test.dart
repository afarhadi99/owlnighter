import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/streaks/streaks_page.dart';
import 'package:owlnighter/services/api/extras_api.dart';

import 'support/fake_api.dart';

MyStats _stats() => MyStats(
      currentStreak: 5,
      longestStreak: 12,
      totalXp: 340,
      xpToday: 20,
      week: fakeWeek(readDays: 3),
    );

Widget _host(StatsApi api) => ProviderScope(
      overrides: [statsApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        // Reduced motion so the NightSky/flame tickers stop for pumpAndSettle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const StreaksPage(),
      ),
    );

void main() {
  group('StreaksPage', () {
    testWidgets('hydrates from GET /v1/me/stats and shows the payoff',
        (tester) async {
      final api = FakeStatsApi(_stats());
      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(api.calls, 1);
      expect(find.text('5'), findsOneWidget); // current streak hero
      expect(find.text('12'), findsOneWidget); // longest
      expect(find.text('340'), findsOneWidget); // total XP
      expect(find.text('Longest'.toUpperCase()), findsOneWidget);
      expect(find.text('Total XP'.toUpperCase()), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
    });

    testWidgets('the week row renders seven day bubbles', (tester) async {
      await tester.pumpWidget(_host(FakeStatsApi(_stats())));
      await tester.pumpAndSettle();

      // 3 of 7 days read → 3 check marks in the week row.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });
  });
}
