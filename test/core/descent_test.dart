/// Descent planner arithmetic, checked against the standard rules of thumb.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/e6b/descent.dart';

void main() {
  DescentPlan plan({
    double from = 6500,
    double to = 1500,
    double gs = 120,
    double? angle,
    double? rate,
  }) =>
      planDescent(
              fromFt: from,
              toFt: to,
              groundspeedKt: gs,
              angleDeg: angle,
              rateFpm: rate)
          .plan!;

  group('by angle', () {
    test('3° from 6,500 to 1,500 ft at 120 kt', () {
      final p = plan(angle: 3);
      // gradient = tan 3° × 6076.12 = 318.4 ft/nm
      expect(p.gradientFtPerNm, closeTo(318.44, 0.01));
      // 5,000 ft / 318.44 = 15.70 nm
      expect(p.distanceNm, closeTo(15.70, 0.01));
      // 318.44 × 120 / 60 = 636.9 fpm (rule of thumb: 120 × 5 = 600)
      expect(p.rateFpm, closeTo(636.9, 0.1));
      // 15.70 nm at 120 kt = 7.85 min
      expect(p.minutes, closeTo(7.85, 0.01));
      expect(p.angleDeg, closeTo(3, 1e-9));
      expect(p.altitudeToLose, 5000);
    });

    test('"3 nm per 1,000 ft" holds for a 3° path', () {
      expect(plan(from: 2500, angle: 3).distanceNm, closeTo(3.14, 0.01));
    });

    test('a faster groundspeed needs more fpm, not more distance', () {
      final slow = plan(angle: 3, gs: 90), fast = plan(angle: 3, gs: 180);
      expect(fast.distanceNm, closeTo(slow.distanceNm, 1e-9));
      expect(fast.rateFpm, closeTo(slow.rateFpm * 2, 1e-9));
    });
  });

  test('by rate: 500 fpm from 6,500 to 1,500 ft at 120 kt', () {
    final p = plan(rate: 500);
    expect(p.minutes, closeTo(10, 1e-9)); // 5,000 / 500
    expect(p.distanceNm, closeTo(20, 1e-9)); // 10 min at 2 nm/min
    expect(p.gradientFtPerNm, closeTo(250, 1e-9));
    expect(p.angleDeg,
        closeTo(math.atan(250 / feetPerNm) * 180 / math.pi, 1e-9));
    expect(p.angleDeg, closeTo(2.36, 0.01));
  });

  group('no plan, with the reason', () {
    DescentProblem? why(
            {double from = 5000,
            double to = 1000,
            double gs = 100,
            double? angle,
            double? rate}) =>
        planDescent(
                fromFt: from,
                toFt: to,
                groundspeedKt: gs,
                angleDeg: angle,
                rateFpm: rate)
            .problem;

    test('target not below', () {
      expect(why(from: 3000, to: 3000, angle: 3), DescentProblem.notBelow);
    });
    test('no groundspeed', () {
      expect(why(gs: 0, angle: 3), DescentProblem.noGroundspeed);
    });
    test('angle of 0 or over 10°', () {
      expect(why(angle: 0), DescentProblem.badAngle);
      expect(why(angle: 12), DescentProblem.badAngle);
    });
    test('rate of 0', () {
      expect(why(rate: 0), DescentProblem.badRate);
    });
  });
}
