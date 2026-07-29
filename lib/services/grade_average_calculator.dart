import '../models/grade.dart';
import '../models/subject.dart';
import 'app_clock.dart';

/// One subject row for student grade summary (LEVEL 2).
class SubjectGradeAverage {
  const SubjectGradeAverage({
    required this.subjectId,
    required this.subjectName,
    required this.average,
    required this.gradeCount,
  });

  final int subjectId;
  final String subjectName;
  final double? average;
  final int gradeCount;

  String get displayAverage => GradeAverageCalculator.format(average);

  String get letterGrade {
    if (average == null) return GradeAverageCalculator.emptyLabel;
    return Grade.letterFromScore(average!);
  }

  String get displayWithLetter {
    if (average == null) return GradeAverageCalculator.emptyLabel;
    return '${GradeAverageCalculator.format(average)} ($letterGrade)';
  }

  /// Compact Mongolian summary line, e.g. `Дундаж: 65.0 (D)`.
  String get averageLine => 'Дундаж: $displayWithLetter';

  /// Compact count line, e.g. `5 дүн`.
  String get countLine => '$gradeCount дүн';
}

/// Shared arithmetic average for class / student / subject grade UIs.
///
/// Always average raw numeric grade records — never averages-of-averages.
class GradeAverageCalculator {
  GradeAverageCalculator._();

  static const emptyLabel = '—';
  static const unknownDateLabel = 'Огноо тодорхойгүй';
  static const emptyTermMessage = 'Энэ улиралд дүн бүртгэгдээгүй байна.';
  static const emptySubjectHistoryMessage =
      'Энэ хичээлийн дүнгийн мэдээлэл алга.';

  /// Mean of valid numeric scores; `null` when none count.
  static double? average(Iterable<Grade> grades) {
    final scores = <double>[];
    for (final grade in grades) {
      final value = double.tryParse(grade.score.trim());
      if (value == null) continue;
      if (value < 0 || value > 100) continue;
      scores.add(value);
    }
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// One decimal place, or [emptyLabel] when null.
  static String format(double? average) {
    if (average == null) return emptyLabel;
    return average.toStringAsFixed(1);
  }

  /// Groups [grades] by stable [Grade.subjectId] (resolved via [subjects]).
  ///
  /// When [onlyWithGrades] is true, subjects with zero matching grades are
  /// omitted (student/guardian summary). Otherwise rows follow [subjects]
  /// catalog order and empty subjects appear with a null average (teacher).
  static List<SubjectGradeAverage> subjectAverages({
    required Iterable<Grade> grades,
    required List<Subject> subjects,
    Map<String, int>? subjectIdByName,
    bool onlyWithGrades = false,
  }) {
    final byId = <int, List<Grade>>{};
    final nameLookup = subjectIdByName ??
        {
          for (final s in subjects) s.name.trim(): s.id,
        };

    for (final grade in grades) {
      final id = grade.subjectId ?? nameLookup[grade.subject.trim()];
      if (id == null) continue;
      byId.putIfAbsent(id, () => <Grade>[]).add(grade);
    }

    final ordered = subjects.toList(growable: false)
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.name.compareTo(b.name);
      });

    final rows = <SubjectGradeAverage>[
      for (final subject in ordered)
        SubjectGradeAverage(
          subjectId: subject.id,
          subjectName: subject.name,
          average: average(byId[subject.id] ?? const <Grade>[]),
          gradeCount: byId[subject.id]?.length ?? 0,
        ),
    ];

    if (!onlyWithGrades) return rows;
    return [
      for (final row in rows)
        if (row.gradeCount > 0) row,
    ];
  }

  /// Newest first by recorded grade date/time.
  ///
  /// Records with no usable timestamp sort to the bottom (not invented dates).
  static List<Grade> sortNewestFirst(Iterable<Grade> grades) {
    final list = grades.toList();
    list.sort((a, b) {
      final aKey = sortTimestampKey(a);
      final bKey = sortTimestampKey(b);
      final aMissing = aKey.isEmpty;
      final bMissing = bKey.isEmpty;
      if (aMissing != bMissing) {
        return aMissing ? 1 : -1;
      }
      if (!aMissing) {
        final byDate = bKey.compareTo(aKey);
        if (byDate != 0) return byDate;
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }

  /// Sortable ISO-ish key; empty when no usable date exists.
  static String sortTimestampKey(Grade grade) {
    final date = grade.gradeDate?.trim();
    if (date != null && date.isNotEmpty) {
      final time = grade.createdAt;
      if (time != null) {
        final hh = time.hour.toString().padLeft(2, '0');
        final mm = time.minute.toString().padLeft(2, '0');
        final ss = time.second.toString().padLeft(2, '0');
        return '${date}T$hh:$mm:$ss';
      }
      return date;
    }
    final created = grade.createdAt;
    if (created != null) return created.toIso8601String();
    final updated = grade.updatedAt;
    if (updated != null) return updated.toIso8601String();
    return '';
  }

  /// Mongolian date label for history rows; never invents a date.
  static String historyDateLabel(Grade grade) {
    final key = grade.gradeDate?.trim();
    if (key != null && key.isNotEmpty) {
      return AppClock.displayLabel(key);
    }
    final created = grade.createdAt;
    if (created != null) {
      return AppClock.mongolianLabel(created);
    }
    return unknownDateLabel;
  }

  /// Recorded time (`HH:mm`) when a real timestamp exists; otherwise null.
  static String? historyTimeLabel(Grade grade) {
    final created = grade.createdAt;
    if (created != null) {
      return AppClock.formatTime(created);
    }
    return null;
  }
}
