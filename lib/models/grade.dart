class Grade {
  const Grade({
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.score,
    required this.term,
    this.letterGrade,
  });

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
    if (value == null) return null;
    return letterFromScore(value);
  }

  String get resolvedLetterGrade {
    if (letterGrade != null && letterGrade!.isNotEmpty) {
      return letterGrade!;
    }
    return tryLetterFromScoreText(score) ?? 'F';
  }

  String get scoreWithLetter => '$score ($resolvedLetterGrade)';
}
