import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/school_settings.dart';
import '../models/student.dart';
import '../services/grade_write_authorization.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import 'student_list_screen.dart';

class BulkGradeEntryScreen extends StatefulWidget {
  const BulkGradeEntryScreen({
    super.key,
    required this.selectedClass,
    required this.store,
    this.initialSubject,
    this.initialTerm,
  });

  final String selectedClass;
  final AppStore store;
  final String? initialSubject;
  final String? initialTerm;

  @override
  State<BulkGradeEntryScreen> createState() => _BulkGradeEntryScreenState();
}

class _BulkGradeEntryScreenState extends State<BulkGradeEntryScreen> {
  List<String> get _subjects {
    final taught = widget.store
        .subjectsTaughtByActiveTeacherInClass(widget.selectedClass)
        .map((s) => s.name)
        .toList();
    if (taught.isNotEmpty) return taught;
    if (widget.store.hasAdminPermissionForActiveSchool) {
      return widget.store.subjects;
    }
    return taught;
  }

  List<String> get _terms => SchoolSettings.semesterOptions;

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, String?> _letterPreviews = {};
  final Map<String, String> _initialScores = {};
  final Map<String, String> _existingGradeIds = {};

  String? _selectedSubject;
  String? _selectedTerm;
  bool _isSaving = false;

  List<Student> get _students => widget.store.studentsFor(widget.selectedClass);

  int? get _subjectId {
    final name = _selectedSubject?.trim();
    if (name == null || name.isEmpty) return null;
    return widget.store.subjectByName(name)?.id;
  }

  GradePermissionResult get _permission {
    final subjectId = _subjectId;
    if (subjectId == null) {
      return const GradePermissionResult.denied(
        GradePermissionResult.subjectMissing,
      );
    }
    return widget.store.canTeacherManageGrades(
      classId: widget.selectedClass,
      subjectId: subjectId,
    );
  }

  bool get _hasValidChangedScore {
    for (final student in _students) {
      final text = _scoreControllers[student.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final score = num.tryParse(text);
      if (score == null || score < 0 || score > 100) continue;
      final initial = _initialScores[student.id] ?? '';
      if (text != initial) return true;
    }
    return false;
  }

  bool get _canSubmit {
    if (_isSaving) return false;
    if (!_permission.allowed) return false;
    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      return false;
    }
    if (_selectedTerm == null || _selectedTerm!.trim().isEmpty) return false;
    return _hasValidChangedScore;
  }

  @override
  void initState() {
    super.initState();
    final subject = widget.initialSubject;
    if (subject != null &&
        (_subjects.contains(subject) ||
            widget.store.hasAdminPermissionForActiveSchool)) {
      _selectedSubject = subject;
    } else if (_subjects.length == 1) {
      _selectedSubject = _subjects.first;
    }
    final term = widget.initialTerm;
    if (term != null && _terms.contains(term)) {
      _selectedTerm = term;
    }
    _syncControllers(_students);
    _preloadExistingScores();
  }

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _preloadExistingScores() {
    final subject = _selectedSubject;
    final term = _selectedTerm;
    if (subject == null || term == null) return;
    for (final student in _students) {
      final grades = widget.store.gradesForStudentContext(
        className: widget.selectedClass,
        studentId: student.id,
        subjectName: subject,
        term: term,
      );
      if (grades.isEmpty) continue;
      final existing = grades.first;
      // Keep id for upsert, but blank/placeholder scores are CREATE not UPDATE.
      _existingGradeIds[student.id] = existing.id;
      if (!Grade.hasEnteredScore(existing)) continue;
      final score = existing.score.trim();
      _initialScores[student.id] = score;
      final controller = _scoreControllers[student.id];
      if (controller != null && controller.text.isEmpty) {
        controller.text = score;
        _letterPreviews[student.id] = Grade.tryLetterFromScoreText(score);
      }
    }
  }

  void _syncControllers(List<Student> students) {
    final ids = {for (final student in students) student.id};

    final removedIds = _scoreControllers.keys
        .where((id) => !ids.contains(id))
        .toList(growable: false);

    for (final student in students) {
      _scoreControllers.putIfAbsent(student.id, () {
        final controller = TextEditingController();
        controller.addListener(() {
          _updateLetterPreview(student.id);
          if (mounted) setState(() {});
        });
        return controller;
      });
    }

    if (removedIds.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final id in removedIds) {
        if (ids.contains(id)) continue;
        _scoreControllers.remove(id)?.dispose();
        _letterPreviews.remove(id);
        _initialScores.remove(id);
        _existingGradeIds.remove(id);
      }
    });
  }

  void _updateLetterPreview(String studentId) {
    final controller = _scoreControllers[studentId];
    if (controller == null) return;

    final letter = Grade.tryLetterFromScoreText(controller.text);
    if (_letterPreviews[studentId] != letter) {
      setState(() => _letterPreviews[studentId] = letter);
    }
  }

  Future<void> _openStudentList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentListScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _syncControllers(_students));
  }

  void _showError(String message, {String? debugDetail}) {
    final text = (kDebugMode && debugDetail != null && debugDetail.isNotEmpty)
        ? '$message\n($debugDetail)'
        : message;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_isSaving || !_canSubmit) return;
    if (!_formKey.currentState!.validate()) return;

    final permission = _permission;
    if (!permission.allowed) {
      _showError(
        'Дүн хадгалах эрхийн тохиргоо таарахгүй байна.',
        debugDetail: permission.debugLabel,
      );
      return;
    }

    final students = _students;
    if (students.isEmpty) return;

    final drafts = <({Grade grade, bool isUpdate})>[];
    for (final student in students) {
      final scoreText = _scoreControllers[student.id]!.text.trim();
      if (scoreText.isEmpty) continue;
      final score = num.tryParse(scoreText);
      if (score == null || score < 0 || score > 100) continue;
      final initial = _initialScores[student.id] ?? '';
      if (scoreText == initial) continue;

      final existingId = _existingGradeIds[student.id];
      Grade? existingGrade;
      if (existingId != null) {
        for (final g in widget.store.gradesForStudentContext(
          className: widget.selectedClass,
          studentId: student.id,
          subjectName: _selectedSubject,
          term: _selectedTerm,
        )) {
          if (g.id == existingId) {
            existingGrade = g;
            break;
          }
        }
      }
      drafts.add((
        grade: Grade(
          id: existingId ?? widget.store.nextGradeId(),
          className: widget.selectedClass,
          studentId: student.id,
          studentName: student.fullName,
          subject: _selectedSubject!,
          subjectId: _subjectId,
          score: scoreText,
          term: _selectedTerm!,
          termId: _selectedTerm!,
          letterGrade: Grade.letterFromScore(score),
        ),
        // Only scored existing rows are updates; blank shells are create/claim.
        isUpdate:
            existingGrade != null && Grade.hasEnteredScore(existingGrade),
      ));
    }

    if (drafts.isEmpty) {
      _showError('Хадгалах өөрчлөгдсөн дүн алга.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final draft in drafts) {
        await widget.store.saveGrade(draft.grade, isUpdate: draft.isUpdate);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ангийн дүн амжилттай хадгалагдлаа')),
      );
      Navigator.pop(context);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on GradeSaveException catch (e) {
      if (!mounted) return;
      _showError(e.message, debugDetail: e.debugCode);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showError(
        Grade.permissionDeniedMessage,
        debugDetail: e.code,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(Grade.genericSaveFailedMessage);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final students = _students;
        _syncControllers(students);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ангийн дүн оруулах'),
            centerTitle: true,
          ),
          body: students.isEmpty
              ? _EmptyStudentsBody(onAddStudents: _openStudentList)
              : Column(
                  children: [
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              '${widget.selectedClass} анги',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSubject,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Хичээл',
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Хичээл сонгох'),
                              icon: const Icon(Icons.arrow_drop_down),
                              items: _subjects
                                  .map(
                                    (subject) => DropdownMenuItem<String>(
                                      value: subject,
                                      child: Text(
                                        subject,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedSubject = value;
                                        _initialScores.clear();
                                        _existingGradeIds.clear();
                                        _preloadExistingScores();
                                      });
                                    },
                              validator: (value) {
                                final selected = value ?? _selectedSubject;
                                if (selected == null || selected.isEmpty) {
                                  return 'Хичээлээ сонгоно уу';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTerm,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Улирал',
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Улирал сонгох'),
                              icon: const Icon(Icons.arrow_drop_down),
                              items: _terms
                                  .map(
                                    (term) => DropdownMenuItem<String>(
                                      value: term,
                                      child: Text(
                                        term,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedTerm = value;
                                        _initialScores.clear();
                                        _existingGradeIds.clear();
                                        _preloadExistingScores();
                                      });
                                    },
                              validator: (value) {
                                final selected = value ?? _selectedTerm;
                                if (selected == null || selected.isEmpty) {
                                  return 'Улирлаа сонгоно уу';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Сурагчдын дүн',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...students.map((student) {
                              final controller = _scoreControllers[student.id]!;
                              final letter = _letterPreviews[student.id];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          student.fullName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: controller,
                                        enabled: !_isSaving,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                          labelText: 'Дүн',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (value) {
                                          final text = value?.trim() ?? '';
                                          if (text.isEmpty) return null;
                                          final score = num.tryParse(text);
                                          if (score == null ||
                                              score < 0 ||
                                              score > 100) {
                                            return '0–100';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 48,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          letter ?? '—',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: letter == null
                                                    ? theme.colorScheme.outline
                                                    : AppColors.grade,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: FilledButton(
                          onPressed: _canSubmit ? _save : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Бүх дүнг хадгалах'),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyStudentsBody extends StatelessWidget {
  const _EmptyStudentsBody({required this.onAddStudents});

  final VoidCallback onAddStudents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Энэ ангид сурагч бүртгэлгүй байна',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddStudents,
            icon: const Icon(Icons.person_add),
            label: const Text('Сурагч нэмэх'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
