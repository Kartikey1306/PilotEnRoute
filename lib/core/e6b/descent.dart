/// Descent planning: where to start down and how fast to descend.
///
/// Pure Dart so the arithmetic can be pinned in host tests.
///
///   gradient (ft/nm) = tan(angle) × 6076.12      3° → 318 ft/nm
///   rate (fpm)       = gradient × groundspeed / 60   3° at 120 kt → 637 fpm
///   distance (nm)    = altitude to lose / gradient
///   time (min)       = distance / groundspeed × 60
///
/// The familiar rules of thumb fall out of these: a 3° path needs about
/// "groundspeed × 5" fpm, and "3 nm per 1,000 ft" (3.14 nm exactly).
library;

import 'dart:math' as math;

/// Feet in one nautical mile.
const double feetPerNm = 6076.12;

class DescentPlan {
  /// Altitude to lose, ft (always > 0).
  final double altitudeToLose;

  /// Distance before the fix to start down, nm.
  final double distanceNm;

  /// Vertical speed to hold, ft/min.
  final double rateFpm;

  /// Time from top of descent to reaching the target altitude, minutes.
  final double minutes;

  /// Descent path angle, degrees.
  final double angleDeg;

  /// Descent gradient, ft per nm.
  final double gradientFtPerNm;

  const DescentPlan({
    required this.altitudeToLose,
    required this.distanceNm,
    required this.rateFpm,
    required this.minutes,
    required this.angleDeg,
    required this.gradientFtPerNm,
  });
}

/// Why no plan could be made, for the screen to say.
enum DescentProblem { notBelow, noGroundspeed, badAngle, badRate }

/// Plans a descent from [fromFt] to [toFt] at [groundspeedKt], either along
/// a path of [angleDeg] or at a vertical speed of [rateFpm] (exactly one of
/// the two). Returns the plan, or the reason there is none.
({DescentPlan? plan, DescentProblem? problem}) planDescent({
  required double fromFt,
  required double toFt,
  required double groundspeedKt,
  double? angleDeg,
  double? rateFpm,
}) {
  assert((angleDeg == null) != (rateFpm == null));
  final lose = fromFt - toFt;
  if (lose <= 0) return (plan: null, problem: DescentProblem.notBelow);
  if (groundspeedKt <= 0) {
    return (plan: null, problem: DescentProblem.noGroundspeed);
  }

  final double gradient;
  if (angleDeg != null) {
    // Real descents are a few degrees; 0 never arrives, 10+ is not a plan.
    if (angleDeg <= 0 || angleDeg > 10) {
      return (plan: null, problem: DescentProblem.badAngle);
    }
    gradient = math.tan(angleDeg * math.pi / 180) * feetPerNm;
  } else {
    if (rateFpm! <= 0) return (plan: null, problem: DescentProblem.badRate);
    gradient = rateFpm / groundspeedKt * 60;
  }

  final distance = lose / gradient;
  final minutes = distance / groundspeedKt * 60;
  return (
    plan: DescentPlan(
      altitudeToLose: lose,
      distanceNm: distance,
      rateFpm: gradient * groundspeedKt / 60,
      minutes: minutes,
      angleDeg: math.atan(gradient / feetPerNm) * 180 / math.pi,
      gradientFtPerNm: gradient,
    ),
    problem: null,
  );
}
