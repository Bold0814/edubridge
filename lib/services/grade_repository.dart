import '../models/grade.dart';

/// Shared grade persistence used by every grade screen.
abstract class GradeRepository {
  /// Loads all grade documents (caller filters in memory by school/class/etc.).
  Future<List<Grade>> loadAll();

  /// Creates a new document at `grades/{grade.id}`.
  Future<void> create(Grade grade);

  /// Updates the existing document with the same [Grade.id].
  /// Must not create a second document.
  Future<void> update(Grade grade);

  /// Deletes `grades/{id}` when present.
  Future<void> delete(String id);
}
