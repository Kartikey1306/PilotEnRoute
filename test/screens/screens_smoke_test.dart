/// Every screen the app ships builds without an exception and shows text.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilot_enroute/features/plan/presentation/airport_screen.dart';
import 'package:pilot_enroute/features/plan/presentation/checklist_screen.dart';
import 'package:pilot_enroute/features/plan/presentation/flight_plan_screen.dart';
import 'package:pilot_enroute/features/home/presentation/go_history_screen.dart';
import 'package:pilot_enroute/features/plan/presentation/plan_screen.dart';
import 'package:pilot_enroute/features/logbook/presentation/logbook_entry_screen.dart';
import 'package:pilot_enroute/features/logbook/presentation/logbook_screen.dart';
import 'package:pilot_enroute/features/settings/presentation/minimums_screen.dart';
import 'package:pilot_enroute/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pilot_enroute/features/profile/presentation/profile_screen.dart';
import 'package:pilot_enroute/features/settings/presentation/reminders_screen.dart';
import 'package:pilot_enroute/features/settings/presentation/settings_screen.dart';
import 'package:pilot_enroute/features/home/presentation/today_screen.dart';
import 'package:pilot_enroute/features/plan/presentation/weather_screen.dart';

import '../support/harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> smokeTest(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(Harness().wrap(screen));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    expect(find.byType(Text), findsAtLeastNWidgets(1));
  }

  final screens = <String, Widget Function()>{
    'TodayScreen': () => const TodayScreen(),
    'LogbookScreen': () => const LogbookScreen(),
    'LogbookEntryScreen': () => const LogbookEntryScreen(),
    'WeatherScreen': () => const WeatherScreen(),
    'PlanScreen': () => const PlanScreen(),
    'AirportScreen': () => const AirportScreen(),
    'ChecklistScreen': () => const ChecklistScreen(),
    'FlightPlanScreen': () => const FlightPlanScreen(),
    'SettingsScreen': () => SettingsScreen(
        isPrivacyOptionsRequired: () async => false,
        showPrivacyOptions: () async {}),
    'ProfileScreen': () => const ProfileScreen(),
    'MinimumsScreen': () => const MinimumsScreen(),
    'RemindersScreen': () => const RemindersScreen(),
    'GoHistoryScreen': () => const GoHistoryScreen(),
    'OnboardingScreen': () => const OnboardingScreen(),
  };
  group('Screen smoke tests — every screen renders', () {
    screens.forEach((name, build) {
      testWidgets('$name renders', (t) => smokeTest(t, build()));
    });
  });
}
