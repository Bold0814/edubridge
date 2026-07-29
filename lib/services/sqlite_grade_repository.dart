import '../models/grade.dart';
import '../repositories/edubridge_repository.dart';
import 'grade_repository.dart';

/// SQLite-backed [GradeRepository] (local mirror / default for tests).
class SqliteGradeRepository implements GradeRepository {
  SqliteGradeRepository(this._repository);

  final EduBridgeRepository _repository;

  @override
  Future<List<Grade>> loadAll() => _repository.loadGrades();

  @override
  Future<void> create(Grade grade) => _repository.insertGrade(grade);

  @override
  Future<void> update(Grade grade) => _repository.updateGrade(grade);

  @override
  Future<void> delete(String id) => _repository.deleteGrade(id);
}
