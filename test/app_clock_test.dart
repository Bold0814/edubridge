import 'package:edubridge/services/app_clock.dart';
import 'package:edubridge/services/school_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(AppClock.debugResetNow);

  test('todayKey matches OS calendar day in Asia/Ulaanbaatar', () {
    final system = DateTime.now();
    final systemKey =
        '${system.year.toString().padLeft(4, '0')}-'
        '${system.month.toString().padLeft(2, '0')}-'
        '${system.day.toString().padLeft(2, '0')}';

    // On a machine already in UTC+8, AppClock today must equal OS date.
    expect(AppClock.todayKey(), systemKey);
    expect(SchoolDate.localDateKey(), systemKey);
  });

  test('UTC morning does not shift school day backward', () {
    // 2026-07-28 07:00 UB == 2026-07-27 23:00 UTC.
    // Using UTC Y/M/D alone would incorrectly yield 2026-07-27.
    final localMorning = DateTime(2026, 7, 28, 7);
    expect(AppClock.dateKeyForInstant(localMorning), '2026-07-28');
    expect(AppClock.todayKey(localMorning), '2026-07-28');

    final asUtc = DateTime.utc(2026, 7, 27, 23);
    expect(AppClock.todayKey(asUtc), '2026-07-28');
  });

  test('nowInUlaanbaatar returns non-UTC calendar fields', () {
    final ub = AppClock.nowInUlaanbaatar(DateTime.utc(2026, 7, 27, 23));
    expect(ub.isUtc, isFalse);
    expect(ub.year, 2026);
    expect(ub.month, 7);
    expect(ub.day, 28);
  });
}
