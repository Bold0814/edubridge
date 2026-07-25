/// Shared subject catalog entry (scoped to a school).
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.schoolId,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String schoolId;
  final bool isActive;
  final int sortOrder;

  static const defaultNames = [
    'Монгол хэл',
    'Математик',
    'Англи хэл',
    'Физик',
    'Хими',
    'Биологи',
    'Түүх',
    'Газар зүй',
    'Мэдээллийн технологи',
  ];

  Subject copyWith({
    String? name,
    String? schoolId,
    bool? isActive,
    int? sortOrder,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
