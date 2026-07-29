import 'package:flutter/material.dart';

import '../../models/school_settings.dart';
import '../../models/student.dart';
import '../../services/grade_average_calculator.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/learner_access_gate.dart';
import 'learner_subject_grade_history_screen.dart';

/// Read-only grades for one child: term → subject averages → history.
class GuardianGradesScreen extends StatefulWidget {
  const GuardianGradesScreen({
    super.key,
    required this.store,
    required this.student,
  });

  final AppStore store;
  final Student student;

  @override
  State<GuardianGradesScreen> createState() => _GuardianGradesScreenState();
}

class _GuardianGradesScreenState extends State<GuardianGradesScreen> {
  late String _selectedTerm;

  @override
  void initState() {
    super.initState();
    _selectedTerm = _resolveInitialTerm();
  }

  String _resolveInitialTerm() {
    final journal = widget.store.journalTermFor(widget.student.className)?.trim();
    if (journal != null &&
        journal.isNotEmpty &&
        SchoolSettings.semesterOptions.contains(journal)) {
      return journal;
    }
    final current = widget.store.schoolSettings.currentSemester.trim();
    if (current.isNotEmpty &&
        SchoolSettings.semesterOptions.contains(current)) {
      return current;
    }
    return SchoolSettings.semesterOptions.first;
  }

  Future<void> _openSubjectHistory({
    required int subjectId,
    required String subjectName,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => LearnerSubjectGradeHistoryScreen(
          store: widget.store,
          student: widget.student,
          subjectId: subjectId,
          subjectName: subjectName,
          term: _selectedTerm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LearnerAccessGate(
      store: widget.store,
      student: widget.student,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final averages = widget.store.subjectAveragesForStudent(
            className: widget.student.className,
            studentId: widget.student.id,
            term: _selectedTerm,
            schoolId: widget.store.activeSchoolId,
            onlyWithGrades: true,
          );

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Дүн'), centerTitle: true),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    0,
                  ),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_selectedTerm),
                    initialValue: _selectedTerm,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Улирал',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      for (final term in SchoolSettings.semesterOptions)
                        DropdownMenuItem(value: term, child: Text(term)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedTerm = value);
                      widget.store.setJournalTerm(
                        widget.student.className,
                        value,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sectionSm,
                    AppSpacing.page,
                    AppSpacing.itemSm,
                  ),
                  child: Text(
                    'Хичээлүүдийн дундаж',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: averages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.page),
                            child: Text(
                              GradeAverageCalculator.emptyTermMessage,
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
                            0,
                            AppSpacing.page,
                            AppSpacing.page,
                          ),
                          itemCount: averages.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.item),
                          itemBuilder: (context, index) {
                            final row = averages[index];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radius,
                                ),
                                onTap: () => _openSubjectHistory(
                                  subjectId: row.subjectId,
                                  subjectName: row.subjectName,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.card,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              row.subjectName,
                                              style: theme
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              row.averageLine,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: AppColors.grade,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              row.countLine,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
