import 'package:flutter/material.dart';

import '../models/school_settings.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'student_grade_detail_screen.dart';

/// LEVEL 1 — Class grade summary: one row per student (term average).
class GradeScreen extends StatefulWidget {
  const GradeScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  @override
  State<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  late String _selectedTerm;

  @override
  void initState() {
    super.initState();
    _selectedTerm = _resolveInitialTerm();
  }

  String _resolveInitialTerm() {
    final journal = widget.store.journalTermFor(widget.selectedClass)?.trim();
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

  Future<void> _openStudent(Student student) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentGradeDetailScreen(
          store: widget.store,
          student: student,
          schoolId: widget.store.activeSchoolId,
          classId: widget.selectedClass,
          term: _selectedTerm,
        ),
      ),
    );
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = widget.store;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final students = store.studentsFor(widget.selectedClass);
        final isEmpty = students.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.selectedClass} · Ангийн дүн'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.page,
                  AppSpacing.page,
                  0,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTerm,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Улирал',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final term in SchoolSettings.semesterOptions)
                      DropdownMenuItem(value: term, child: Text(term)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedTerm = value);
                    store.setJournalTerm(widget.selectedClass, value);
                  },
                ),
              ),
              Expanded(
                child: isEmpty
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
                        padding: const EdgeInsets.all(AppSpacing.page),
                        itemCount: students.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final average = store.averageGradeForClassStudent(
                            className: widget.selectedClass,
                            studentId: student.id,
                            term: _selectedTerm,
                          );
                          final averageLabel = store.formatGradeAverage(
                            average,
                          );

                          return Material(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radius,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radius,
                              ),
                              onTap: () => _openStudent(student),
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
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      averageLabel,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
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
              ),
            ],
          ),
        );
      },
    );
  }
}
