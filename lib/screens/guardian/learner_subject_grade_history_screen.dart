import 'package:flutter/material.dart';

import '../../models/grade.dart';
import '../../models/student.dart';
import '../../services/grade_average_calculator.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/learner_access_gate.dart';

/// Read-only subject grade history for student / guardian.
class LearnerSubjectGradeHistoryScreen extends StatelessWidget {
  const LearnerSubjectGradeHistoryScreen({
    super.key,
    required this.store,
    required this.student,
    required this.subjectId,
    required this.subjectName,
    required this.term,
  });

  final AppStore store;
  final Student student;
  final int subjectId;
  final String subjectName;
  final String term;

  List<Grade> _grades() {
    return GradeAverageCalculator.sortNewestFirst(
      store.gradesForStudentContext(
        className: student.className,
        studentId: student.id,
        subjectId: subjectId,
        term: term,
        schoolId: store.activeSchoolId,
      ),
    );
  }

  String? _teacherName(Grade grade) {
    final id = grade.teacherId?.trim();
    if (id != null && id.isNotEmpty) {
      final teacher = store.teacherById(id);
      if (teacher != null) return teacher.fullName;
    }
    return store
        .teacherForClassSubjectName(student.className, grade.subject)
        ?.fullName;
  }

  String? _summaryTeacherName(List<Grade> grades) {
    for (final grade in grades) {
      final name = _teacherName(grade);
      if (name != null && name.isNotEmpty) return name;
    }
    return store
        .teacherForClassSubjectName(student.className, subjectName)
        ?.fullName;
  }

  String? _noteOrTitle(Grade grade) {
    final note = grade.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    final title = grade.title?.trim();
    if (title != null &&
        title.isNotEmpty &&
        title != grade.subject.trim()) {
      return title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LearnerAccessGate(
      store: store,
      student: student,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final grades = _grades();
          final average = GradeAverageCalculator.average(grades);
          final averageLabel = average == null
              ? GradeAverageCalculator.emptyLabel
              : '${GradeAverageCalculator.format(average)} '
                    '(${Grade.letterFromScore(average)})';
          final teacherName = _summaryTeacherName(grades);

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(
              title: Text('$subjectName · $term'),
              centerTitle: true,
            ),
            body: grades.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      child: Text(
                        GradeAverageCalculator.emptySubjectHistoryMessage,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.card),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дундаж дүн: $averageLabel',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.grade,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (teacherName != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Багш: $teacherName',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionSm),
                      Text(
                        'Дүнгийн түүх',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      for (final grade in grades) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.card),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  GradeAverageCalculator.historyDateLabel(
                                    grade,
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (GradeAverageCalculator.historyTimeLabel(
                                      grade,
                                    ) !=
                                    null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    GradeAverageCalculator.historyTimeLabel(
                                      grade,
                                    )!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  grade.scoreWithLetter,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.grade,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_teacherName(grade) != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Багш: ${_teacherName(grade)}'),
                                ],
                                if (_noteOrTitle(grade) != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Тэмдэглэл: ${_noteOrTitle(grade)}'),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.item),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}
