import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/student.dart';
import '../state/app_store.dart';
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
  static const _subjects = [
    'Монгол хэл',
    'Математик',
    'Англи хэл',
    'Физик',
    'Хими',
    'Биологи',
    'Түүх',
    'Газар зүй',
    'Мэдээллийн технологи',
  ];

  static const _terms = [
    '1-р улирал',
    '2-р улирал',
    '3-р улирал',
    '4-р улирал',
  ];

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, String?> _letterPreviews = {};

  String? _selectedSubject;
  String? _selectedTerm;
  bool _isSaving = false;

  List<Student> get _students => widget.store.studentsFor(widget.selectedClass);

  @override
  void initState() {
    super.initState();
    final subject = widget.initialSubject;
    if (subject != null && _subjects.contains(subject)) {
      _selectedSubject = subject;
    }
    final term = widget.initialTerm;
    if (term != null && _terms.contains(term)) {
      _selectedTerm = term;
    }
    _syncControllers(_students);
  }

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<Student> students) {
    final ids = {for (final student in students) student.id};

    final removedIds = _scoreControllers.keys
        .where((id) => !ids.contains(id))
        .toList(growable: false);

    for (final student in students) {
      _scoreControllers.putIfAbsent(student.id, () {
        final controller = TextEditingController();
        controller.addListener(() => _updateLetterPreview(student.id));
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

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final students = _students;
    if (students.isEmpty) return;

    final grades = <Grade>[];
    for (final student in students) {
      final scoreText = _scoreControllers[student.id]!.text.trim();
      final score = num.parse(scoreText);
      grades.add(
        Grade(
          className: widget.selectedClass,
          studentId: student.id,
          studentName: student.fullName,
          subject: _selectedSubject!,
          score: scoreText,
          term: _selectedTerm!,
          letterGrade: Grade.letterFromScore(score),
        ),
      );
    }

    setState(() => _isSaving = true);
    widget.store.addGrades(grades);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ангийн дүн амжилттай хадгалагдлаа')),
    );
    Navigator.pop(context);
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
                              onChanged: (value) {
                                setState(() => _selectedSubject = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
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
                              onChanged: (value) {
                                setState(() => _selectedTerm = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
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
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                          labelText: 'Дүн',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Дүн оруулна уу';
                                          }
                                          final score = num.tryParse(
                                            value.trim(),
                                          );
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
                                                    : Colors.purple,
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
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: const Text('Бүх дүнг хадгалах'),
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
