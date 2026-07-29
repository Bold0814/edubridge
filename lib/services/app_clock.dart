import 'package:flutter/foundation.dart';

/// Single shared clock for school calendar dates.
///
/// All modules must obtain "now" / "today" from here — never invent calendar
/// days via UTC components, hardcoded dates, or yesterday fallbacks.
class AppClock {
  AppClock._();

  static DateTime Function() _nowFn = DateTime.now;

  /// Asia/Ulaanbaatar is permanently UTC+8 (no DST).
  static const ulaanbaatarOffset = Duration(hours: 8);

  /// Operating-system instant (`DateTime.now()` unless overridden in tests).
  static DateTime now() => _nowFn();

  /// Wall-clock time in Asia/Ulaanbaatar (calendar fields are UB local).
  ///
  /// Returns a non-UTC [DateTime] whose year/month/day/hour match UB, so
  /// callers never accidentally read UTC Y/M/D from an `isUtc: true` value.
  static DateTime nowInUlaanbaatar([DateTime? clock]) {
    final utc = (clock ?? now()).toUtc();
    final shifted = utc.add(ulaanbaatarOffset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  /// Today's calendar day in Asia/Ulaanbaatar (time stripped).
  static DateTime today([DateTime? clock]) {
    final ub = nowInUlaanbaatar(clock);
    return DateTime(ub.year, ub.month, ub.day);
  }

  /// Today's `yyyy-MM-dd` key in Asia/Ulaanbaatar.
  static String todayKey([DateTime? clock]) => formatDateKey(today(clock));

  /// Formats a calendar Y/M/D as `yyyy-MM-dd` (ignores time-of-day).
  ///
  /// Prefer [dateKeyForInstant] when [value] is a wall-clock / UTC instant.
  static String formatDateKey(DateTime value) {
    return keyFromParts(value.year, value.month, value.day);
  }

  /// Converts any instant to Asia/Ulaanbaatar, then builds `yyyy-MM-dd`.
  static String dateKeyForInstant(DateTime instant) {
    return formatDateKey(nowInUlaanbaatar(instant));
  }

  static String keyFromParts(int year, int month, int day) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? tryParseDateKey(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  static String displayLabel(String dateKey) {
    final parsed = tryParseDateKey(dateKey);
    if (parsed == null) return dateKey;
    return '${parsed.year} оны ${parsed.month} сарын ${parsed.day}';
  }

  static String mongolianLabel(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return '${day.year} оны ${day.month} сарын ${day.day}';
  }

  /// `HH:mm` in Asia/Ulaanbaatar for an instant.
  static String formatTime(DateTime? instant) {
    if (instant == null) return '--:--';
    final ub = nowInUlaanbaatar(instant);
    final h = ub.hour.toString().padLeft(2, '0');
    final m = ub.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Temporary verification that system / journal / attendance share one day.
  static void debugLogSchoolDates({
    String? journalDateKey,
    String? attendanceDateKey,
  }) {
    final system = now();
    final systemKey = formatDateKey(
      DateTime(system.year, system.month, system.day),
    );
    final today = todayKey();
    debugPrint('System Date: $systemKey (${system.toIso8601String()})');
    debugPrint('Journal Date: ${journalDateKey ?? today}');
    debugPrint('Attendance DateKey: ${attendanceDateKey ?? today}');
  }

  /// Test-only override. Always restore with [debugResetNow] in tearDown.
  @visibleForTesting
  static void debugSetNow(DateTime Function() nowFn) {
    _nowFn = nowFn;
  }

  @visibleForTesting
  static void debugResetNow() {
    _nowFn = DateTime.now;
  }
}
