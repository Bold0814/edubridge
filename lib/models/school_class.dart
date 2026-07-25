/// School class. [id] is the SQLite primary key (equals [name] for migrated data).
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.schoolId,
    this.homeroomTeacherId,
  });

  final String id;
  final String name;
  final String schoolId;
  final String? homeroomTeacherId;

  SchoolClass copyWith({
    String? name,
    String? schoolId,
    String? homeroomTeacherId,
    bool clearHomeroom = false,
  }) {
    return SchoolClass(
      id: id,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      homeroomTeacherId: clearHomeroom
          ? null
          : (homeroomTeacherId ?? this.homeroomTeacherId),
    );
  }
}
