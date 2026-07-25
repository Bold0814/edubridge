import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'grade_create_screen.dart';
import 'student_grade_detail_screen.dart';

/// Class grade overview: one row per student with calculated average.
class GradeScreen extends StatelessWidget {
  const GradeScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  String? get _activeSubjectName => store.activeSubjectName;

  Future<void> _openCreateScreen(BuildContext context) async {
    final subjectId = store.activeContext.subjectId;
    final initialSubject = subjectId != null
        ? store.subjectById(subjectId)?.name
        : store.journalSubjectFor(selectedClass);

    await Navigator.push<Grade>(
      context,
      MaterialPageRoute(
        builder: (context) => GradeCreateScreen(
          className: selectedClass,
          store: store,
          initialSubject: initialSubject,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openStudent(BuildContext context, Student student) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentGradeDetailScreen(
          store: store,
          student: student,
          schoolId: store.activeSchoolId,
          classId: selectedClass,
          subjectId: store.activeContext.subjectId,
          subjectName: _activeSubjectName,
          term: store.journalTermFor(selectedClass),
        ),
      ),
    );
    if (!context.mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final students = store.studentsFor(selectedClass);
        final subjectName = _activeSubjectName;
        final isEmpty = students.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('$selectedClass · Ангийн дүн'),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreateScreen(context),
            tooltip: 'Дүн оруулах',
            child: const Icon(Icons.add),
          ),
          body: isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Text(
                      'Сурагч бүртгээгүй байна',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    88,
                  ),
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final average = store.averageGradeForClassStudent(
                      className: selectedClass,
                      studentId: student.id,
                      subjectName: subjectName,
                    );
                    final averageLabel = store.formatGradeAverage(average);

                    return Material(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        onTap: () => _openStudent(context, student),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                averageLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: average == null
                                      ? AppColors.onSurfaceVariant
                                      : AppColors.grade,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
