/// Third audit round: dates after the flight, future logbook entries, the
/// crosswind limit, spreadsheet-safe CSV, and tolerant weather parsing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/legality/private_pilot_progress.dart';
import 'package:pilot_enroute/core/logbook/logbook_csv.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';
import 'package:pilot_enroute/core/minimums/minimums_check.dart';
import 'package:pilot_enroute/core/minimums/personal_minimums.dart';
import 'package:pilot_enroute/core/weather/awc_models.dart';

void main() {
  final flight = DateTime(2026, 11, 13, 9);

  LegalityReport run(PilotProfile p) => const LegalityEngine().evaluate(
        entries: [
          LogbookEntry(
            date: DateTime(2026, 10, 1),
            aircraftType: 'C172',
            tailNumber: 'N1',
            from: 'KPAO',
            to: 'KPAO',
            totalTime: 1,
            categoryClass: 'ASEL',
            dayTakeoffs: 3,
            dayLandings: 3,
            dayFullStopLandings: 3,
          ),
        ],
        profile: p,
        flight: PlannedFlight(date: flight, categoryClass: 'ASEL'),
      );

  final profile = PilotProfile(
    medicalKind: MedicalKind.third,
    medicalExamDate: DateTime(2026, 1, 10),
    age40OrOlderAtExam: false,
    flightReviewDate: DateTime(2026, 1, 10),
    homeCategoryClass: 'ASEL',
  );

  group('dates after the flight do not count (61.23, 61.56)', () {
    test('a medical examined after the flight', () {
      final r = run(profile.copyWith(medicalExamDate: DateTime(2027, 6, 1)))
          .rule(RuleId.medical);
      expect(r.state, RuleState.lapsed);
      expect(r.summary, 'Exam date 1 Jun 2027 is after this flight');
    });

    test('a flight review dated after the flight', () {
      final r = run(profile.copyWith(flightReviewDate: DateTime(2027, 6, 1)))
          .rule(RuleId.flightReview);
      expect(r.state, isNot(RuleState.valid));
    });

    test('BasicMed done after the flight', () {
      final r = run(profile.copyWith(
        medicalKind: MedicalKind.basicMed,
        basicMedExamDate: DateTime(2026, 1, 1),
        basicMedCourseDate: DateTime(2027, 6, 1),
      )).rule(RuleId.medical);
      expect(r.state, RuleState.lapsed);
      expect(r.summary, 'Course date 1 Jun 2027 is after this flight');
    });

    test('dates on or before the flight still count', () {
      final r = run(profile.copyWith(medicalExamDate: DateTime(2026, 11, 13)));
      expect(r.rule(RuleId.medical).state, RuleState.valid);
      expect(r.rule(RuleId.flightReview).state, RuleState.valid);
    });
  });

  test('61.109(a) progress ignores entries dated in the future', () {
    final p = privatePilotProgress(entries: [
      LogbookEntry(
        date: DateTime(2027, 1, 1),
        aircraftType: 'C172',
        tailNumber: 'N1',
        from: 'KPAO',
        to: 'KPAO',
        totalTime: 40,
        dualReceived: 20,
        categoryClass: 'ASEL',
      ),
    ], now: flight);
    expect(p.items.every((i) => !i.met), isTrue);
  });

  group('crosswind is compared unrounded', () {
    MinimumLine xw(int windFrom, int speed, int rwyTrue, int limit) {
      final r = checkAgainst(
        source: 'METAR',
        set: MinimumsSet(maxCrosswindKt: limit),
        ceilingFt: null,
        clouds: const [],
        visibility: null,
        wind: Wind.from(windFrom, speed, null),
        runways: [RunwayInfo(id: '04/22', alignmentTrue: rwyTrue)],
      );
      return r.lines.firstWhere((l) => l.key == 'crosswind');
    }

    test('10.4 kt is outside a 10 kt limit, and says 10.4', () {
      // 270/15 on runway 22 at 226° true: 15·sin 44° = 10.42 kt.
      final l = xw(270, 15, 46, 10);
      expect(l.state, CheckState.outside);
      expect(l.observed, startsWith('10.4 kt'));
      expect(l.outsidePhrase, startsWith('crosswind 10.4 kt'));
    });

    test('9.6 kt is within a 10 kt limit (near)', () {
      // 270/15 on runway at 230° true: 15·sin 40° = 9.64 kt.
      final l = xw(270, 15, 50, 10);
      expect(l.state, CheckState.near);
      expect(l.observed, startsWith('10 kt'));
    });
  });

  group('CSV', () {
    LogbookEntry entry(String remarks, {String type = 'C172'}) => LogbookEntry(
          date: DateTime(2026, 10, 1),
          aircraftType: type,
          tailNumber: 'N1',
          from: 'KPAO',
          to: 'KSQL',
          totalTime: 1.2,
          categoryClass: 'ASEL',
          remarks: remarks,
        );

    test('formulas are written as text and read back exactly', () {
      final csv = logbookToCsv([
        entry('=HYPERLINK("http://x","y")', type: '@SUM(A1)'),
      ]);
      expect(csv, isNot(contains(',=HYPERLINK')));
      expect(csv, contains("'@SUM(A1)"));
      expect(csv, contains('"\'=HYPERLINK(""http://x"",""y"")"'));

      final back = logbookFromCsv(csv);
      expect(back.entries.single.remarks, '=HYPERLINK("http://x","y")');
      expect(back.entries.single.aircraftType, '@SUM(A1)');
    });

    test('ordinary text is unchanged', () {
      expect(csvText('Pattern work'), 'Pattern work');
      expect(csvUntext("'Tis fine"), "'Tis fine");
    });

    test('rows of empty cells from a spreadsheet are skipped', () {
      final csv = '${logbookToCsv([entry('ok')])}'
          '${List.filled(csvHeader.length - 1, ',').join()}\r\n'
          '${List.filled(csvHeader.length - 1, ',').join()}\r\n';
      final r = logbookFromCsv(csv);
      expect(r.entries, hasLength(1));
      expect(r.errors, isEmpty);
    });

    test('US dates and h:mm times as Excel re-saves them', () {
      final csv = logbookToCsv([entry('ok')])
          .replaceFirst('2026-10-01', '10/1/2026')
          .replaceFirst(',1.2,', ',1:12,');
      final r = logbookFromCsv(csv);
      expect(r.errors, isEmpty);
      expect(r.entries.single.date, DateTime(2026, 10, 1));
      expect(r.entries.single.totalTime, closeTo(1.2, 1e-9));
    });
  });

  group('weather numbers that arrive as text', () {
    test('wind "280" at "12" reads, not throws', () {
      final w = Wind.from('280', '12', null)!;
      expect(w.speedKt, 12);
      expect(w.directionTrue, 280);
    });

    test('a VV layer is a ceiling', () {
      expect(const CloudLayer('VV', 300).isCeiling, isTrue);
    });
  });

  group('type rating (61.57(a)/(b) "and type, if a type rating is required")',
      () {
    LegalityReport typed(String type, List<String> loggedTypes) =>
        const LegalityEngine().evaluate(
          entries: [
            for (final t in loggedTypes)
              LogbookEntry(
                date: DateTime(2026, 10, 1),
                aircraftType: t,
                tailNumber: 'N1',
                from: 'KPAO',
                to: 'KPAO',
                totalTime: 1,
                categoryClass: 'AMEL',
                dayTakeoffs: 3,
                dayLandings: 3,
                dayFullStopLandings: 3,
              ),
          ],
          profile: profile,
          flight: PlannedFlight(
              date: flight,
              categoryClass: 'AMEL',
              passengers: true,
              typeRating: type),
        );

    test('landings in another type do not count', () {
      final r = typed('C525', ['BE58']).rule(RuleId.dayPassengers);
      expect(r.state, isNot(RuleState.valid));
      expect(r.shortfall, contains('C525 (type rating)'));
    });

    test('landings in the same type count, however it was written', () {
      expect(typed('C525', ['c-525']).rule(RuleId.dayPassengers).state,
          RuleState.valid);
    });

    test('no type rating: any type of the class counts, as before', () {
      expect(typed('', ['BE58']).rule(RuleId.dayPassengers).state,
          RuleState.valid);
    });
  });

  test('61.109(a) items the logbook cannot show count once marked done', () {
    final p = privatePilotProgress(
        entries: const [], now: flight, confirmed: {'61.109(a)(5)(iii)'});
    final towered =
        p.items.firstWhere((i) => i.cite == '61.109(a)(5)(iii)');
    expect(towered.met, isTrue);
    expect(towered.selfConfirmed, isTrue);
    final xc = p.items.firstWhere((i) => i.cite == '61.109(a)(5)(ii)');
    expect(xc.met, isFalse);
    expect(xc.tracked, isFalse);
  });
}
