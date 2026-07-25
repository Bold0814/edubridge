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
  });

  final String id;
  final String className;
  final String studentId;
  final String studentName;
  final String subject;
  final String score;
  final String term;
  final String? letterGrade;

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
    );
  }
}
