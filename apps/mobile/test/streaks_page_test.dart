import 'package:design_system/design_system.dart' show OwlMascot, OwlState;
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

MyStats _statsNotReadToday() => MyStats(
      currentStreak: 5,
      longestStreak: 12,
      totalXp: 340,
      xpToday: 0,
      week: fakeWeek(readDays: 0),
    );

Widget _host(StatsApi api, {DateTime? now}) => ProviderScope(
      overrides: [statsApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        // Reduced motion so the NightSky/flame tickers stop for pumpAndSettle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: StreaksPage(now: now),
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

    testWidgets(
        'not read today + night hour shows the angry mood banner',
        (tester) async {
      final api = FakeStatsApi(_statsNotReadToday());
      final nightNow = DateTime(2026, 1, 1, 22, 0); // well inside 21:00-05:00
      await tester.pumpWidget(_host(api, now: nightNow));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'You still haven’t read tonight! Your streak is on the line.',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is OwlMascot && w.state == OwlState.angry,
        ),
        findsOneWidget,
      );
    });
  });
}
