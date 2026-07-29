import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared grade record used by teacher, student, and guardian screens.
///
/// Firestore collection: `grades/{id}`.
/// [className] is the class id (legacy column name). [subject] is the display
/// name; [subjectId] is preferred for filtering when present.
class Grade {
  const Grade({
    required this.id,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.score,
    required this.term,
    this.letterGrade,
    this.schoolId,
    this.subjectId,
    this.teacherId,
    this.termId,
    this.gradeType = defaultGradeType,
    this.title,
    this.note,
    this.gradeDate,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.updatedByUid,
  });

  static const collection = 'grades';
  static const defaultGradeType = 'score';

  /// User-visible failure while creating or updating a grade.
  static const missingStudentIdMessage =
      'Сурагч сонгогдоогүй байна. Сурагчаа дахин сонгоно уу.';
  static const missingSubjectIdMessage =
      'Хичээлийн мэдээлэл олдсонгүй. Хичээлээ дахин сонгоно уу.';
  static const missingTermIdMessage =
      'Улирал сонгогдоогүй байна. Улирлаа дахин сонгоно уу.';
  static const missingSchoolIdMessage =
      'Сургууль сонгогдоогүй байна.';
  static const missingTeacherIdMessage =
      'Багшийн мэдээлэл олдсонгүй. Дахин нэвтэрнэ үү.';
  static const missingClassIdMessage = 'Анги сонгогдоогүй байна.';
  static const permissionDeniedMessage =
      'Дүн хадгалах эрхийн тохиргоо таарахгүй байна.';
  static const genericSaveFailedMessage =
      'Дүн хадгалахад алдаа гарлаа.';

  final String id;

  /// Class id (stored historically as `class_name` / `className`).
  final String className;
  final String studentId;
  final String studentName;

  /// Subject display name (legacy; keep in sync with [subjectId] when possible).
  final String subject;
  final String score;
  final String term;
  final String? letterGrade;

  final String? schoolId;
  final int? subjectId;
  final String? teacherId;

  /// Term key; defaults to [term] when omitted on legacy rows.
  final String? termId;
  final String gradeType;
  final String? title;
  final String? note;
  final String? gradeDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? updatedByUid;

  String get classId => className;
  String get createdByTeacherId => teacherId ?? '';

  String get resolvedTermId {
    final id = termId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return term.trim();
  }

  static String letterFromScore(num score) {
    if (score >= 95) return 'A+';
    if (score >= 90) return 'A';
    if (score >= 85) return 'B+';
    if (score >= 80) return 'B';
    if (score >= 75) return 'C+';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  static String? tryLetterFromScoreText(String scoreText) {
    final value = num.tryParse(scoreText.trim());
    if (value == null || value < 0 || value > 100) return null;
    return letterFromScore(value);
  }

  /// Validates a numeric score in 0–100. Throws [ArgumentError] if invalid.
  static num parseAndValidateScore(String scoreText) {
    final value = num.tryParse(scoreText.trim());
    if (value == null || value < 0 || value > 100) {
      throw ArgumentError.value(
        scoreText,
        'score',
        'Score must be a number between 0 and 100',
      );
    }
    return value;
  }

  String get resolvedLetterGrade {
    if (letterGrade != null && letterGrade!.isNotEmpty) {
      return letterGrade!;
    }
    return tryLetterFromScoreText(score) ?? 'F';
  }

  String get scoreWithLetter => '$score ($resolvedLetterGrade)';

  Grade copyWith({
    String? studentId,
    String? studentName,
    String? subject,
    String? score,
    String? term,
    String? letterGrade,
    String? schoolId,
    int? subjectId,
    String? teacherId,
    String? termId,
    String? gradeType,
    String? title,
    String? note,
    String? gradeDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
    bool clearNote = false,
  }) {
    return Grade(
      id: id,
      className: className,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      subject: subject ?? this.subject,
      score: score ?? this.score,
      term: term ?? this.term,
      letterGrade: letterGrade ?? this.letterGrade,
      schoolId: schoolId ?? this.schoolId,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      termId: termId ?? this.termId,
      gradeType: gradeType ?? this.gradeType,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      gradeDate: gradeDate ?? this.gradeDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }

  /// Firestore create payload. [createdAt] / [updatedAt] may be server timestamps.
  /// Omits null optional fields so the SDK does not reject the write.
  Map<String, Object?> toFirestoreCreateMap({
    required Object createdAt,
    required Object updatedAt,
  }) {
    return _withoutNulls({
      'id': id,
      'schoolId': schoolId,
      'classId': className,
      'studentId': studentId,
      'studentName': studentName,
      'subjectId': subjectId,
      'subject': subject,
      'teacherId': teacherId,
      'termId': resolvedTermId,
      'term': term,
      'score': score,
      'letterGrade': letterGrade ?? resolvedLetterGrade,
      'gradeType': gradeType,
      'title': title ?? subject,
      'note': note,
      'gradeDate': gradeDate,
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid ?? createdByUid,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  }

  /// Firestore update payload. Does not include [createdAt] or [createdByUid].
  Map<String, Object?> toFirestoreUpdateMap({required Object updatedAt}) {
    return _withoutNulls({
      'id': id,
      'schoolId': schoolId,
      'classId': className,
      'studentId': studentId,
      'studentName': studentName,
      'subjectId': subjectId,
      'subject': subject,
      'teacherId': teacherId,
      'termId': resolvedTermId,
      'term': term,
      'score': score,
      'letterGrade': letterGrade ?? resolvedLetterGrade,
      'gradeType': gradeType,
      'title': title ?? subject,
      'note': note,
      'gradeDate': gradeDate,
      'updatedByUid': updatedByUid,
      'updatedAt': updatedAt,
    });
  }

  static Map<String, Object?> _withoutNulls(Map<String, Object?> raw) {
    return {
      for (final entry in raw.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  /// Safe parse for legacy / partial Firestore documents.
  factory Grade.fromFirestore(String docId, Map<String, dynamic> data) {
    final classId =
        (data['classId'] ?? data['className'] ?? data['class_name'] ?? '')
            .toString();
    final subjectName = (data['subject'] ?? data['subjectName'] ?? '')
        .toString();
    final term = (data['term'] ?? data['termId'] ?? '').toString();
    final score = (data['score'] ?? '').toString();
    final letter = data['letterGrade']?.toString() ?? data['letter_grade']?.toString();

    return Grade(
      id: (data['id'] ?? docId).toString(),
      className: classId,
      studentId: (data['studentId'] ?? data['student_id'] ?? '').toString(),
      studentName:
          (data['studentName'] ?? data['student_name'] ?? '').toString(),
      subject: subjectName,
      score: score,
      term: term,
      letterGrade: (letter == null || letter.isEmpty) ? null : letter,
      schoolId: _optionalString(data['schoolId'] ?? data['school_id']),
      subjectId: _optionalInt(data['subjectId'] ?? data['subject_id']),
      teacherId: _optionalString(data['teacherId'] ?? data['teacher_id']),
      termId: _optionalString(data['termId'] ?? data['term_id']) ??
          (term.isEmpty ? null : term),
      gradeType: _optionalString(data['gradeType'] ?? data['grade_type']) ??
          defaultGradeType,
      title: _optionalString(data['title']),
      note: _optionalString(data['note']),
      gradeDate: _optionalString(data['gradeDate'] ?? data['grade_date']),
      createdAt: _optionalDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _optionalDateTime(data['updatedAt'] ?? data['updated_at']),
      createdByUid: _optionalString(data['createdByUid'] ?? data['created_by_uid']),
      updatedByUid: _optionalString(data['updatedByUid'] ?? data['updated_by_uid']),
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return DateTime.tryParse(value.toString());
  }
}

/// Thrown when grade create/update validation or persistence fails.
class GradeSaveException implements Exception {
  const GradeSaveException(this.message, {this.debugCode});

  final String message;
  final String? debugCode;

  @override
  String toString() => message;
}
