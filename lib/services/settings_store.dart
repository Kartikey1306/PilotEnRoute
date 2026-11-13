import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/legality/pilot_profile.dart';
import '../core/minimums/personal_minimums.dart';
import '../core/reminders/reminder_plan.dart';

/// Everything the pilot sets up: home airport, profile, minimums, reminder
/// switches, and whether onboarding is done. All of it stays on the device
/// (SharedPreferences); there is no account and nothing is uploaded.
class SettingsStore extends ChangeNotifier {
  SettingsStore({
    bool onboardingDone = false,
    String homeAirport = '',
    PilotProfile profile = PilotProfile.empty,
    PersonalMinimums minimums = PersonalMinimums.blank,
    Set<ReminderKind>? reminderKinds,
    Set<String>? progressConfirmed,
  })  : _onboardingDone = onboardingDone,
        _homeAirport = homeAirport,
        _profile = profile,
        _minimums = minimums,
        _reminderKinds = {...(reminderKinds ?? ReminderKind.values)},
        _progressConfirmed = {...?progressConfirmed};

  static const kOnboarding = 'onboarding_done_v1';
  static const kHomeAirport = 'home_airport';
  static const kProfile = 'pilot_profile_v1';
  static const kMinimums = 'personal_minimums_v1';
  static const kReminderKinds = 'reminder_kinds_v1';
  static const kProgressConfirmed = 'ppl_progress_confirmed_v1';

  bool _onboardingDone;
  String _homeAirport;
  PilotProfile _profile;
  PersonalMinimums _minimums;
  final Set<ReminderKind> _reminderKinds;
  final Set<String> _progressConfirmed;

  bool get onboardingDone => _onboardingDone;
  String get homeAirport => _homeAirport;
  PilotProfile get profile => _profile;
  PersonalMinimums get minimums => _minimums;
  Set<ReminderKind> get reminderKinds => Set.unmodifiable(_reminderKinds);

  /// 61.109(a) items the logbook cannot show (distances, towered airports)
  /// that the student has marked done, by citation.
  Set<String> get progressConfirmed => Set.unmodifiable(_progressConfirmed);

  /// Reads what was saved. Missing or unreadable values fall back to the
  /// empty defaults — never to sample data.
  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, Object?>? json(String key) {
      final raw = prefs.getString(key);
      if (raw == null) return null;
      try {
        final v = jsonDecode(raw);
        return v is Map ? v.cast<String, Object?>() : null;
      } catch (_) {
        return null;
      }
    }

    var profile = json(kProfile) == null
        ? PilotProfile.empty
        : PilotProfile.fromJson(json(kProfile)!);
    // The name typed on the old Profile screen still heads the PDF export.
    final legacyName = prefs.getString('profile_name');
    if (profile.name.isEmpty && legacyName != null && legacyName.isNotEmpty) {
      profile = profile.copyWith(name: legacyName);
    }
    final kinds = prefs.getStringList(kReminderKinds);
    return SettingsStore(
      onboardingDone: prefs.getBool(kOnboarding) ?? false,
      homeAirport: prefs.getString(kHomeAirport) ?? '',
      profile: profile,
      minimums: PersonalMinimums.fromJson(json(kMinimums)),
      reminderKinds:
          kinds?.map(ReminderKind.fromName).whereType<ReminderKind>().toSet(),
      progressConfirmed: prefs.getStringList(kProgressConfirmed)?.toSet(),
    );
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> setHomeAirport(String icao) async {
    _homeAirport = icao.trim().toUpperCase();
    notifyListeners();
    await (await _prefs).setString(kHomeAirport, _homeAirport);
  }

  Future<void> setProfile(PilotProfile p) async {
    _profile = p;
    notifyListeners();
    final prefs = await _prefs;
    await prefs.setString(kProfile, jsonEncode(p.toJson()));
    // The logbook PDF reads this: a cleared name must not linger there.
    if (p.name.isNotEmpty) {
      await prefs.setString('profile_name', p.name);
    } else {
      await prefs.remove('profile_name');
    }
  }

  Future<void> setMinimums(PersonalMinimums m) async {
    _minimums = m;
    notifyListeners();
    await (await _prefs).setString(kMinimums, jsonEncode(m.toJson()));
  }

  Future<void> setReminderKind(ReminderKind kind, bool on) async {
    if (on) {
      _reminderKinds.add(kind);
    } else {
      _reminderKinds.remove(kind);
    }
    notifyListeners();
    await (await _prefs)
        .setStringList(kReminderKinds, _reminderKinds.map((k) => k.name).toList());
  }

  Future<void> setProgressConfirmed(String cite, bool done) async {
    done ? _progressConfirmed.add(cite) : _progressConfirmed.remove(cite);
    notifyListeners();
    await (await _prefs)
        .setStringList(kProgressConfirmed, _progressConfirmed.toList());
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    notifyListeners();
    await (await _prefs).setBool(kOnboarding, true);
  }
}
