import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/school_settings.dart';
import '../models/student.dart';
import '../services/grade_write_authorization.dart';
import '../state/app_store.dart';

class GradeCreateScreen extends StatefulWidget {
  const GradeCreateScreen({
    super.key,
    required this.className,
    required this.store,
    this.existing,
    this.initialStudent,
    this.initialSubject,
    this.initialTerm,
    this.lockSubject = false,
  });

  final String className;
  final AppStore store;
  final Grade? existing;
  final Student? initialStudent;
  final String? initialSubject;
  final String? initialTerm;
  final bool lockSubject;

  @override
  State<GradeCreateScreen> createState() => _GradeCreateScreenState();
}

class _GradeCreateScreenState extends State<GradeCreateScreen> {
  List<String> get _terms => SchoolSettings.semesterOptions;

  List<String> get _subjects {
    final taught = widget.store
        .subjectsTaughtByActiveTeacherInClass(widget.className)
        .map((s) => s.name)
        .toList();
    if (taught.isNotEmpty) return taught;
    if (widget.store.hasAdminPermissionForActiveSchool) {
      return widget.store.subjects;
    }
    return taught;
  }

  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();

  Student? _selectedStudent;
  String? _selectedSubject;
  String? _selectedTerm;
  String? _previewLetter;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scoreController.addListener(_updateLetterPreview);
    final existing = widget.existing;
    if (existing != null) {
      _scoreController.text = existing.score;
      if (_subjects.contains(existing.subject)) {
        _selectedSubject = existing.subject;
      } else {
        _selectedSubject = existing.subject;
      }
      if (_terms.contains(existing.term)) {
        _selectedTerm = existing.term;
      }
      final students = widget.store.studentsFor(widget.className);
      for (final item in students) {
        if (item.id == existing.studentId) {
          _selectedStudent = item;
          break;
        }
      }
    } else {
      final initialStudent = widget.initialStudent;
      if (initialStudent != null) {
        _selectedStudent = initialStudent;
      }
      final lockedName = widget.store.activeContext.subjectId != null
          ? widget.store
                .subjectById(widget.store.activeContext.subjectId!)
                ?.name
          : null;
      final initialSubject = lockedName ?? widget.initialSubject;
      if (initialSubject != null &&
          (_subjects.contains(initialSubject) ||
              widget.lockSubject ||
              lockedName != null)) {
        _selectedSubject = initialSubject;
      } else if (_subjects.length == 1) {
        _selectedSubject = _subjects.first;
      }
      final initialTerm = widget.initialTerm;
      if (initialTerm != null && _terms.contains(initialTerm)) {
        _selectedTerm = initialTerm;
      }
    }
    _updateLetterPreview();
  }

  @override
  void dispose() {
    _scoreController.removeListener(_updateLetterPreview);
    _scoreController.dispose();
    super.dispose();
  }

  void _updateLetterPreview() {
    final letter = Grade.tryLetterFromScoreText(_scoreController.text);
    if (letter != _previewLetter) {
      setState(() => _previewLetter = letter);
    }
  }

  void _showError(String message, {String? debugCode}) {
    final text = (kDebugMode && debugCode != null && debugCode.isNotEmpty)
        ? '$message ($debugCode)'
        : message;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    // Prefer explicit state over FormField values (Student equality / lock UI).
    final student = _selectedStudent;
    final subjectName = _selectedSubject?.trim();
    final term = _selectedTerm?.trim();
    final scoreText = _scoreController.text.trim();

    if (student == null || student.id.trim().isEmpty) {
      _showError(Grade.missingStudentIdMessage);
      return;
    }
    if (subjectName == null || subjectName.isEmpty) {
      _showError(Grade.missingSubjectIdMessage);
      return;
    }
    if (term == null || term.isEmpty) {
      _showError(Grade.missingTermIdMessage);
      return;
    }

    final subject = widget.store.subjectByName(subjectName);
    if (subject == null) {
      _showError(Grade.missingSubjectIdMessage);
      return;
    }

    final permission = widget.store.canTeacherManageGrades(
      classId: widget.className,
      subjectId: subject.id,
    );
    if (!permission.allowed) {
      _showError(
        Grade.permissionDeniedMessage,
        debugCode: permission.debugLabel,
      );
      return;
    }

    final letter = Grade.letterFromScore(num.parse(scoreText));
    final existing = widget.existing;
    final draft = Grade(
      id: existing?.id ?? widget.store.nextGradeId(),
      className: widget.className,
      studentId: student.id,
      studentName: student.fullName,
      subject: subject.name,
      subjectId: subject.id,
      score: scoreText,
      term: term,
      termId: term,
      letterGrade: letter,
    );

    setState(() => _saving = true);
    try {
      final saved = await widget.store.saveGrade(
        draft,
        isUpdate: existing != null && Grade.hasEnteredScore(existing),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дүн амжилттай хадгалагдлаа.')),
      );
      Navigator.pop(context, saved);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } on GradeSaveException catch (e) {
      if (!mounted) return;
      _showError(e.message, debugCode: e.debugCode);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? Grade.permissionDeniedMessage
          : Grade.genericSaveFailedMessage;
      _showError(
        message,
        debugCode: e.code == 'permission-denied'
            ? GradePermissionResult.firestoreDenied
            : e.code,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _showError(
        e.message?.toString() ?? Grade.genericSaveFailedMessage,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(Grade.genericSaveFailedMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.store.studentsFor(widget.className);
    final theme = Theme.of(context);
    final canSubmit = students.isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Дүн засах' : 'Дүн оруулах'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.className} анги',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Энэ ангид сурагч байхгүй байна. Эхлээд сурагч нэмнэ үү.',
                ),
              ),
            DropdownButtonFormField<String>(
              key: ValueKey('grade-student-${_selectedStudent?.id}'),
              initialValue: _selectedStudent?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Сурагч',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Сурагч сонгох'),
              icon: const Icon(Icons.arrow_drop_down),
              items: students
                  .map(
                    (student) => DropdownMenuItem<String>(
                      value: student.id,
                      child: Text(
                        student.fullName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: students.isEmpty || _saving
                  ? null
                  : (value) {
                      Student? match;
                      for (final item in students) {
                        if (item.id == value) {
                          match = item;
                          break;
                        }
                      }
                      setState(() => _selectedStudent = match);
                    },
              validator: (value) {
                final id = value ?? _selectedStudent?.id;
                if (id == null || id.isEmpty) {
                  return 'Сурагчаа сонгоно уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if ((widget.lockSubject ||
                    widget.store.activeContext.subjectId != null) &&
                _selectedSubject != null)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Хичээл',
                  border: OutlineInputBorder(),
                ),
                child: Text(_selectedSubject!),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey('grade-subject-$_selectedSubject'),
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
                        child: Text(subject, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _selectedSubject = value);
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
            TextFormField(
              controller: _scoreController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Дүн',
                border: const OutlineInputBorder(),
                suffixText: _previewLetter,
                helperText: _previewLetter == null
                    ? null
                    : 'Үсгэн дүн: $_previewLetter',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Дүн оруулна уу';
                }
                final score = num.tryParse(value.trim());
                if (score == null || score < 0 || score > 100) {
                  return '0–100 хооронд дүн оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('grade-term-$_selectedTerm'),
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
                      child: Text(term, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _selectedTerm = value);
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
            FilledButton(
              onPressed: canSubmit ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Дүн хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
