import 'app_clock.dart';

/// School calendar helpers — thin facade over [AppClock].
///
/// Prefer [AppClock] for new call sites. Kept so existing imports keep working.
class SchoolDate {
  SchoolDate._();

  static const ulaanbaatarOffset = AppClock.ulaanbaatarOffset;

  static DateTime nowInUlaanbaatar([DateTime? clock]) =>
      AppClock.nowInUlaanbaatar(clock);

  static String localDateKey([DateTime? clock]) => AppClock.todayKey(clock);

  static String formatDateKey(DateTime value) => AppClock.formatDateKey(value);

  static String keyFromParts(int year, int month, int day) =>
      AppClock.keyFromParts(year, month, day);

  static DateTime? tryParseDateKey(String raw) => AppClock.tryParseDateKey(raw);

  static String displayLabel(String dateKey) => AppClock.displayLabel(dateKey);
}
