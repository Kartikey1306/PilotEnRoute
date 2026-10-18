import 'dart:async';

import 'package:agl_i18n/agl_i18n.dart';
import 'package:agl_observability/agl_observability.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'core/services/ad_service.dart';
import 'core/errors/error_reporter.dart';
import 'core/services/notification_service.dart';
import 'data/repositories/practice_store.dart';
import 'data/repositories/settings_store.dart';

export 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Crash reporting, before anything that could fail. Inactive and
  // harmless until the Firebase config files are added.
  await AglCrash.init(appName: 'PilotEnRoute');
  await AglInsights.init(appName: 'PilotEnRoute');
  ErrorReporter.sink = (error, stack, {context}) =>
      AglCrash.recordError(error, stack, reason: context);
  ErrorReporter.install();

  // Timezone data for scheduling lapse reminders.
  tz.initializeTimeZones();

  // A failing plugin must degrade its own feature, never the first frame.
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }

  // AdMob gathers UMP consent; not awaited so the consent dialog never sits
  // over a black screen. Ad call sites wait for consent on their own.
  unawaited(AdService().initialize());

  final settings = await SettingsStore.load();
  final practice = await PracticeStore.load();
  final locale = AglLocaleController();
  await locale.load();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  runApp(PilotEnRouteApp(
      settings: settings, practice: practice, locale: locale));
}
