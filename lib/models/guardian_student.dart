/// Link between a guardian and a student with a relationship label.
class GuardianStudent {
  const GuardianStudent({
    required this.guardianId,
    required this.studentId,
    required this.relationship,
  });

  final String guardianId;
  final String studentId;
  final String relationship;

  static const relationshipOptions = [
    'Ээж',
    'Аав',
    'Асран хамгаалагч',
    'Эмээ',
    'Өвөө',
    'Ах',
    'Эгч',
  ];
}
