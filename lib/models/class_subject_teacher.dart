/// Assignment of one teacher to one subject within a class.
class ClassSubjectTeacher {
  const ClassSubjectTeacher({
    required this.classId,
    required this.subjectId,
    required this.teacherId,
  });

  final String classId;
  final int subjectId;
  final String teacherId;
}
