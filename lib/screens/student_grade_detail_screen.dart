import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/school_settings.dart';
import '../models/student.dart';
import '../services/grade_average_calculator.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
import 'grade_create_screen.dart';

/// Student grades: LEVEL 2 subject averages, or LEVEL 3 subject history.
///
/// Does not skip to individual records from the class summary. Individual
/// grade rows appear only when a subject is selected.
class StudentGradeDetailScreen extends StatefulWidget {
  const StudentGradeDetailScreen({
    super.key,
    required this.store,
    required this.student,
    required this.classId,
    this.schoolId,
    this.subjectId,
    this.subjectName,
    this.term,
  });

  final AppStore store;

  /// Source-of-truth student row ([Student.id] == [Grade.studentId]).
  final Student student;
  final String? schoolId;
  final String classId;
  final int? subjectId;
  final String? subjectName;
  final String? term;

  @override
  State<StudentGradeDetailScreen> createState() =>
      _StudentGradeDetailScreenState();
}

enum _GradeLoadState { loading, ready, error }

class _StudentGradeDetailScreenState extends State<StudentGradeDetailScreen> {
  _GradeLoadState _loadState = _GradeLoadState.loading;
  late String _selectedTerm;

  int? get _subjectId {
    if (widget.subjectId != null) return widget.subjectId;
    final named = widget.subjectName?.trim();
    if (named != null && named.isNotEmpty) {
      return widget.store.subjectByName(named)?.id;
    }
    return null;
  }

  String? get _subjectName {
    final id = _subjectId;
    if (id != null) {
      return widget.store.subjectById(id)?.name.trim();
    }
    final named = widget.subjectName?.trim();
    if (named == null || named.isEmpty) return null;
    return named;
  }

  bool get _showRecords => _subjectId != null;

  String get _title {
    if (_showRecords) {
      return '${_subjectName ?? ''} · $_selectedTerm';
    }
    return '${widget.student.fullName} · Дүн';
  }

  String get _emptyMessage {
    if (_showRecords) {
      return GradeAverageCalculator.emptySubjectHistoryMessage;
    }
    return GradeAverageCalculator.emptyTermMessage;
  }

  @override
  void initState() {
    super.initState();
    _selectedTerm = _resolveInitialTerm(widget.term);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _queryGrades();
        setState(() => _loadState = _GradeLoadState.ready);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('StudentGradeDetail load error: $e\n$st');
        }
        setState(() => _loadState = _GradeLoadState.error);
      }
    });
  }

  String _resolveInitialTerm(String? preferred) {
    final fromNav = preferred?.trim();
    if (fromNav != null &&
        fromNav.isNotEmpty &&
        SchoolSettings.semesterOptions.contains(fromNav)) {
      return fromNav;
    }
    final journal = widget.store.journalTermFor(widget.classId)?.trim();
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

  List<Grade> _queryGrades() {
    return widget.store.gradesForStudentContext(
      className: widget.classId,
      studentId: widget.student.id,
      subjectId: _subjectId,
      term: _selectedTerm,
      schoolId: widget.schoolId ?? widget.store.activeSchoolId,
    );
  }

  Future<void> _openCreate({Grade? existing}) async {
    final result = await Navigator.push<Grade>(
      context,
      MaterialPageRoute(
        builder: (context) => GradeCreateScreen(
          className: widget.classId,
          store: widget.store,
          existing: existing,
          initialStudent: widget.student,
          initialSubject: existing?.subject ?? _subjectName,
          initialTerm: existing?.term ?? _selectedTerm,
          lockSubject: _subjectId != null,
        ),
      ),
    );
    if (!context.mounted) return;
    if (result != null) setState(() {});
  }

  Future<void> _openSubjectRecords({
    required int subjectId,
    required String subjectName,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentGradeDetailScreen(
          store: widget.store,
          student: widget.student,
          schoolId: widget.schoolId ?? widget.store.activeSchoolId,
          classId: widget.classId,
          subjectId: subjectId,
          subjectName: subjectName,
          term: _selectedTerm,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onMenuSelected(Grade item, String action) async {
    if (action == 'edit') {
      if (!widget.store.canEditGradeRecord(item)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStore.recordOwnOnlyMessage)),
        );
        return;
      }
      await _openCreate(existing: item);
      return;
    }
    if (action == 'delete') {
      if (!widget.store.canDeleteGradeRecord(item)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStore.recordDeleteDeniedMessage)),
        );
        return;
      }
      final ok = await confirmDelete(context);
      if (!ok || !mounted) return;
      try {
        await widget.store.deleteGrade(item.id);
      } on PermissionDeniedException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      if (!mounted) return;
      showDeletedSnackBar(context);
      setState(() {});
    }
  }

  bool get _canEditSubject {
    final subjectId = _subjectId;
    if (subjectId == null) return false;
    return widget.store.teacherCanEditClassSubject(
      classId: widget.classId,
      subjectId: subjectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final grades = _loadState == _GradeLoadState.ready
            ? GradeAverageCalculator.sortNewestFirst(_queryGrades())
            : const <Grade>[];

        return Scaffold(
          appBar: AppBar(title: Text(_title), centerTitle: true),
          // Entry FAB only on LEVEL 3 when the teacher may edit that subject.
          floatingActionButton: _showRecords && _canEditSubject
              ? FloatingActionButton(
                  onPressed: () => _openCreate(),
                  tooltip: 'Дүн оруулах',
                  child: const Icon(Icons.add),
                )
              : null,
          body: switch (_loadState) {
            _GradeLoadState.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            _GradeLoadState.error => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Text(
                  'Дүнгийн мэдээлэл ачаалж чадсангүй',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _GradeLoadState.ready => Column(
              children: [
                if (!_showRecords)
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
                        widget.store.setJournalTerm(widget.classId, value);
                      },
                    ),
                  ),
                Expanded(
                  child: _showRecords
                      ? _GradeRecordsBody(
                          store: widget.store,
                          grades: grades,
                          emptyMessage: _emptyMessage,
                          onEdit: (grade) => _openCreate(existing: grade),
                          onMenu: _onMenuSelected,
                        )
                      : _SubjectAveragesBody(
                          store: widget.store,
                          selectedClass: widget.classId,
                          student: widget.student,
                          schoolId:
                              widget.schoolId ?? widget.store.activeSchoolId,
                          term: _selectedTerm,
                          onSubjectTap: _openSubjectRecords,
                        ),
                ),
              ],
            ),
          },
        );
      },
    );
  }
}

class _SubjectAveragesBody extends StatelessWidget {
  const _SubjectAveragesBody({
    required this.store,
    required this.selectedClass,
    required this.student,
    required this.onSubjectTap,
    this.schoolId,
    this.term,
  });

  final AppStore store;
  final String selectedClass;
  final Student student;
  final String? schoolId;
  final String? term;
  final void Function({required int subjectId, required String subjectName})
  onSubjectTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final averages = store.subjectAveragesForStudent(
      className: selectedClass,
      studentId: student.id,
      term: term,
      schoolId: schoolId,
    );

    if (averages.every((row) => row.gradeCount == 0)) {
      return Center(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: averages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final row = averages[index];
        final hasRecords = row.gradeCount > 0;
        final label = row.displayWithLetter;

        return Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            onTap: hasRecords
                ? () => onSubjectTap(
                    subjectId: row.subjectId,
                    subjectName: row.subjectName,
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.subjectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasRecords)
                          Text(
                            row.countLine,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasRecords ? 'Дундаж: $label' : label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: row.average == null
                          ? AppColors.onSurfaceVariant
                          : AppColors.grade,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasRecords) ...[
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ] else
                    const SizedBox(width: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GradeRecordsBody extends StatelessWidget {
  const _GradeRecordsBody({
    required this.store,
    required this.grades,
    required this.emptyMessage,
    required this.onEdit,
    required this.onMenu,
  });

  final AppStore store;
  final List<Grade> grades;
  final String emptyMessage;
  final ValueChanged<Grade> onEdit;
  final void Function(Grade grade, String action) onMenu;

  String _dateLabel(Grade grade) {
    return GradeAverageCalculator.historyDateLabel(grade);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (grades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Text(
            emptyMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.page,
        AppSpacing.page,
        88,
      ),
      children: [
        for (final item in grades)
          Builder(
            builder: (context) {
              final canEdit = store.canEditGradeRecord(item);
              final canDelete = store.canDeleteGradeRecord(item);
              return Card(
                child: ListTile(
                  onTap: canEdit ? () => onEdit(item) : null,
                  onLongPress: (canEdit || canDelete)
                      ? () async {
                          final action = await showEditDeleteMenu(
                            context,
                            canEdit: canEdit,
                            canDelete: canDelete,
                          );
                          if (action == null) return;
                          onMenu(item, action);
                        }
                      : null,
                  contentPadding: const EdgeInsets.all(AppSpacing.card),
                  title: Text(
                    _dateLabel(item),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: _subtitle(item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.scoreWithLetter,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.grade,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (canEdit || canDelete)
                        PopupMenuButton<String>(
                          tooltip: 'Цэс',
                          onSelected: (value) => onMenu(item, value),
                          itemBuilder: (context) => [
                            if (canEdit)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('✏️ Засах'),
                              ),
                            if (canDelete)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('🗑 Устгах'),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget? _subtitle(Grade item) {
    final parts = <String>[];
    final title = item.title?.trim();
    if (title != null &&
        title.isNotEmpty &&
        title != item.subject.trim()) {
      parts.add(title);
    } else if (item.gradeType.isNotEmpty &&
        item.gradeType != Grade.defaultGradeType) {
      parts.add(item.gradeType);
    }
    final teacherId = item.teacherId?.trim();
    if (teacherId != null && teacherId.isNotEmpty) {
      final teacher = store.teacherById(teacherId);
      if (teacher != null) parts.add(teacher.fullName);
    }
    final note = item.note?.trim();
    if (note != null && note.isNotEmpty) parts.add(note);
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }
}
