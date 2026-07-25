import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
import 'grade_create_screen.dart';

/// Student grade detail: subject averages, or locked subject/term records.
///
/// Uses [AppStore.gradesForStudentContext] — the same filter as the student
/// summary average. Source-of-truth student key: [Student.id].
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

  int? get _subjectId {
    if (widget.subjectId != null) return widget.subjectId;
    // An explicit subjectName from navigation must not be overridden by
    // ambient ActiveAppContext.subjectId.
    final named = widget.subjectName?.trim();
    if (named != null && named.isNotEmpty) return null;
    return widget.store.activeContext.subjectId;
  }

  String? get _subjectName {
    if (_subjectId != null) {
      return widget.store.subjectById(_subjectId!)?.name.trim();
    }
    final named = widget.subjectName?.trim();
    if (named == null || named.isEmpty) return null;
    return named;
  }

  String? get _term {
    final t = widget.term?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  bool get _showRecords {
    final subject = _subjectName;
    return subject != null && subject.isNotEmpty;
  }

  String get _title {
    final parts = <String>[widget.student.fullName];
    final subject = _subjectName;
    final term = _term;
    if (subject != null) parts.add(subject);
    if (term != null) parts.add(term);
    return parts.join(' · ');
  }

  String get _emptyMessage {
    if (_subjectName != null && _term != null) {
      return 'Энэ хичээл, улиралд дүн бүртгээгүй байна';
    }
    if (_subjectName != null) {
      return 'Энэ хичээлд дүн бүртгээгүй байна';
    }
    return 'Дүн бүртгээгүй байна';
  }

  List<Grade> _queryGrades() {
    return widget.store.gradesForStudentContext(
      className: widget.classId,
      studentId: widget.student.id,
      subjectId: _subjectId,
      subjectName: _subjectId == null ? _subjectName : null,
      term: _term,
    );
  }

  void _logContext(List<Grade> grades) {
    if (!kDebugMode) return;
    debugPrint(
      'StudentGradeDetail '
      'schoolId=${widget.schoolId ?? widget.store.activeSchoolId} '
      'classId=${widget.classId} '
      'studentId=${widget.student.id} '
      'subjectId=$_subjectId '
      'subjectName=$_subjectName '
      'term=$_term '
      'teacherId=${widget.store.activeContext.teacherId} '
      'matchCount=${grades.length}',
    );
    for (final g in grades.take(5)) {
      debugPrint(
        '  grade id=${g.id} studentId=${g.studentId} '
        'subject=${g.subject} term=${g.term} score=${g.score}',
      );
    }
    if (grades.isEmpty) {
      final allForStudent = widget.store.gradesForStudentContext(
        className: widget.classId,
        studentId: widget.student.id,
      );
      debugPrint(
        '  unfiltered student grades=${allForStudent.length} '
        'subjects=${allForStudent.map((g) => g.subject).toSet()} '
        'terms=${allForStudent.map((g) => g.term).toSet()}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final grades = _queryGrades();
        _logContext(grades);
        setState(() => _loadState = _GradeLoadState.ready);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('StudentGradeDetail load error: $e\n$st');
        }
        setState(() => _loadState = _GradeLoadState.error);
      }
    });
  }

  Future<void> _openCreate({Grade? existing, String? subjectName}) async {
    final result = await Navigator.push<Grade>(
      context,
      MaterialPageRoute(
        builder: (context) => GradeCreateScreen(
          className: widget.classId,
          store: widget.store,
          existing: existing,
          initialStudent: widget.student,
          initialSubject: existing?.subject ?? subjectName ?? _subjectName,
          initialTerm: existing?.term ?? _term,
        ),
      ),
    );
    if (!context.mounted) return;
    if (result != null) {
      setState(() {});
    }
  }

  Future<void> _openSubjectRecords(String subjectName) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentGradeDetailScreen(
          store: widget.store,
          student: widget.student,
          schoolId: widget.schoolId ?? widget.store.activeSchoolId,
          classId: widget.classId,
          subjectName: subjectName,
          term: _term,
        ),
      ),
    );
    if (!context.mounted) return;
    setState(() {});
  }

  Future<void> _onMenuSelected(Grade item, String action) async {
    if (action == 'edit') {
      await _openCreate(existing: item, subjectName: item.subject);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDelete(context);
      if (!ok || !mounted) return;
      await widget.store.deleteGrade(item.id);
      if (!mounted) return;
      showDeletedSnackBar(context);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final grades = _loadState == _GradeLoadState.ready
            ? _queryGrades()
            : const <Grade>[];

        return Scaffold(
          appBar: AppBar(title: Text(_title), centerTitle: true),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreate(
              subjectName: _showRecords
                  ? _subjectName
                  : widget.store.activeSubjectName ??
                        widget.store.journalSubjectFor(widget.classId),
            ),
            tooltip: 'Дүн оруулах',
            child: const Icon(Icons.add),
          ),
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
            _GradeLoadState.ready =>
              _showRecords
                  ? _GradeRecordsBody(
                      grades: grades,
                      emptyMessage: _emptyMessage,
                      onEdit: (grade) => _openCreate(
                        existing: grade,
                        subjectName: _subjectName,
                      ),
                      onMenu: _onMenuSelected,
                    )
                  : _SubjectAveragesBody(
                      store: widget.store,
                      selectedClass: widget.classId,
                      student: widget.student,
                      term: _term,
                      onSubjectTap: _openSubjectRecords,
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
    this.term,
  });

  final AppStore store;
  final String selectedClass;
  final Student student;
  final String? term;
  final ValueChanged<String> onSubjectTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = store.subjects;
    if (subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Text(
            'Хичээл бүртгээгүй байна',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.page,
        AppSpacing.page,
        88,
      ),
      itemCount: subjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final grades = store.gradesForStudentContext(
          className: selectedClass,
          studentId: student.id,
          subjectName: subject,
          term: term,
        );
        final average = store.averageScore(grades);
        final label = store.formatGradeAverage(average);
        final hasRecords = grades.isNotEmpty;

        return Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            onTap: hasRecords ? () => onSubjectTap(subject) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (grades.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${grades.length} дүн',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: average == null
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
    required this.grades,
    required this.emptyMessage,
    required this.onEdit,
    required this.onMenu,
  });

  final List<Grade> grades;
  final String emptyMessage;
  final ValueChanged<Grade> onEdit;
  final void Function(Grade grade, String action) onMenu;

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
          Card(
            child: ListTile(
              onTap: () => onEdit(item),
              onLongPress: () async {
                final action = await showEditDeleteMenu(context);
                if (action == null) return;
                onMenu(item, action);
              },
              contentPadding: const EdgeInsets.all(AppSpacing.card),
              title: Text(
                item.subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item.term),
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
                  PopupMenuButton<String>(
                    tooltip: 'Цэс',
                    onSelected: (value) => onMenu(item, value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('✏️ Засах')),
                      PopupMenuItem(value: 'delete', child: Text('🗑 Устгах')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
