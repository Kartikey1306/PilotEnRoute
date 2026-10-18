import 'package:agl_i18n/agl_i18n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/plan/presentation/airport_screen.dart';
import 'core/router/app_shell.dart';
import 'features/plan/presentation/charts_screen.dart';
import 'features/plan/presentation/checklist_screen.dart';
import 'features/plan/presentation/documents_screen.dart';
import 'features/plan/presentation/e6b_screen.dart';
import 'features/plan/presentation/flight_plan_screen.dart';
import 'features/plan/presentation/fuel_screen.dart';
import 'features/home/presentation/go_history_screen.dart';
import 'features/settings/presentation/minimums_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/settings/presentation/reminders_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/home/presentation/today_screen.dart';
import 'features/plan/presentation/weather_screen.dart';
import 'features/plan/presentation/weight_balance_screen.dart';
import 'core/services/ad_service.dart';
import 'features/plan/data/document_service.dart';
import 'features/plan/data/flight_plan_service.dart';
import 'data/repositories/logbook_service.dart';
import 'data/repositories/practice_store.dart';
import 'features/settings/data/reminder_service.dart';
import 'data/repositories/settings_store.dart';
import 'data/repositories/weather_service.dart';
import 'core/theme/theme.dart';

class PilotEnRouteApp extends StatefulWidget {
  const PilotEnRouteApp({
    super.key,
    this.settings,
    this.logbook,
    this.weather,
    this.practice,
    this.locale,
    this.clock,
  });

  /// Injected in tests; loaded from the device in [main].
  final SettingsStore? settings;
  final LogbookService? logbook;
  final WeatherService? weather;
  final PracticeStore? practice;
  final AglLocaleController? locale;
  final DateTime Function()? clock;

  @override
  State<PilotEnRouteApp> createState() => _PilotEnRouteAppState();
}

class _PilotEnRouteAppState extends State<PilotEnRouteApp> {
  late final SettingsStore _settings = widget.settings ?? SettingsStore();
  late final LogbookService _logbook = widget.logbook ?? LogbookService();
  late final WeatherService _weather = widget.weather ?? WeatherService();
  late final PracticeStore _practice = widget.practice ?? PracticeStore();
  late final AglLocaleController _locale =
      widget.locale ?? AglLocaleController();
  late final ReminderService _reminders =
      ReminderService(settings: _settings, logbook: _logbook, clock: widget.clock);

  @override
  void initState() {
    super.initState();
    _reminders.attach();
    DocumentService.onChanged = () {
      if (_settings.onboardingDone) _reminders.reschedule();
    };
    _logbook.init();
  }

  @override
  void dispose() {
    _reminders.dispose();
    DocumentService.onChanged = null;
    super.dispose();
  }

  static Route<dynamic> panel(Widget w, RouteSettings s) =>
      MaterialPageRoute(settings: s, builder: (_) => PanelTheme(child: w));

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: _settings),
        ChangeNotifierProvider<LogbookService>.value(value: _logbook),
        ChangeNotifierProvider<WeatherService>.value(value: _weather),
        ChangeNotifierProvider<PracticeStore>.value(value: _practice),
        ChangeNotifierProvider<ReminderService>.value(value: _reminders),
        ChangeNotifierProvider<AglLocaleController>.value(value: _locale),
        ChangeNotifierProvider(create: (_) => FlightPlanService()),
        // A process-wide singleton: provided with `.value` so the provider
        // never disposes it.
        ChangeNotifierProvider<AdService>.value(value: AdService()),
      ],
      child: ListenableBuilder(
        listenable: _locale,
        builder: (context, _) => MaterialApp(
          // Twelve languages for the framework and shared strings; `locale`
          // null follows the device unless the user picked one.
          localizationsDelegates: aglLocalizationsDelegates(null),
          supportedLocales: AglLocales.standard,
          locale: _locale.locale,
          title: 'PilotEnRoute',
          debugShowCheckedModeBanner: false,
          theme: buildSkyTheme(Brightness.light),
          darkTheme: buildSkyTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          home: RootGate(clock: widget.clock),
          onGenerateRoute: (s) {
            switch (s.name) {
              case '/e6b':
                return panel(const E6BScreen(), s);
              case '/weight-balance':
                return panel(const WeightBalanceScreen(), s);
              case '/fuel':
                return panel(const FuelScreen(), s);
              case '/flight-plan':
                return panel(const FlightPlanScreen(), s);
              case '/checklist':
                return panel(const ChecklistScreen(), s);
              case '/documents':
                return panel(const DocumentsScreen(), s);
              case '/charts':
                return panel(const ChartsScreen(), s);
              case '/airport':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const AirportScreen());
              case '/settings':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const SettingsScreen());
              case '/minimums':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const MinimumsScreen());
              case '/reminders':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const RemindersScreen());
              case '/history':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const GoHistoryScreen());
              case '/go':
                return MaterialPageRoute(
                    settings: s,
                    builder: (_) => TodayScreen(clock: widget.clock));
              case '/weather':
                return MaterialPageRoute(
                    settings: s, builder: (_) => const WeatherScreen());
            }
            return null;
          },
        ),
      ),
    );
  }
}

/// Onboarding until it is finished once; then Home, on every launch.
class RootGate extends StatelessWidget {
  const RootGate({super.key, this.clock});
  final DateTime Function()? clock;

  /// Every named route the app registers (asserted by the boot test).
  static const routes = <String>[
    '/e6b',
    '/weight-balance',
    '/fuel',
    '/flight-plan',
    '/checklist',
    '/documents',
    '/charts',
    '/airport',
    '/settings',
    '/minimums',
    '/reminders',
    '/history',
    '/go',
    '/weather',
  ];

  @override
  Widget build(BuildContext context) {
    final done = context.watch<SettingsStore>().onboardingDone;
    return done ? AppShell(clock: clock) : const OnboardingScreen();
  }
}
