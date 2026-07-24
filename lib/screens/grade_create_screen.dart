import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../models/student.dart';
import '../state/app_store.dart';

class GradeCreateScreen extends StatefulWidget {
  const GradeCreateScreen({
    super.key,
    required this.className,
    required this.store,
  });

  final String className;
  final AppStore store;

  @override
  State<GradeCreateScreen> createState() => _GradeCreateScreenState();
}

class _GradeCreateScreenState extends State<GradeCreateScreen> {
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

  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();
  final _termController = TextEditingController(text: '1-р улирал');

  Student? _selectedStudent;
  String? _selectedSubject;
  String? _previewLetter;

  @override
  void initState() {
    super.initState();
    _scoreController.addListener(_updateLetterPreview);
  }

  @override
  void dispose() {
    _scoreController.removeListener(_updateLetterPreview);
    _scoreController.dispose();
    _termController.dispose();
    super.dispose();
  }

  void _updateLetterPreview() {
    final letter = Grade.tryLetterFromScoreText(_scoreController.text);
    if (letter != _previewLetter) {
      setState(() => _previewLetter = letter);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final scoreText = _scoreController.text.trim();
    final student = _selectedStudent!;
    final grade = Grade(
      className: widget.className,
      studentId: student.id,
      studentName: student.fullName,
      subject: _selectedSubject!,
      score: scoreText,
      term: _termController.text.trim(),
      letterGrade: Grade.letterFromScore(num.parse(scoreText)),
    );

    widget.store.addGrade(grade);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Дүн амжилттай хадгалагдлаа.')),
    );
    Navigator.pop(context, grade);
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.store.studentsFor(widget.className);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Дүн оруулах'), centerTitle: true),
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
            DropdownButtonFormField<Student>(
              initialValue: _selectedStudent,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Сурагч',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Сурагч сонгох'),
              icon: const Icon(Icons.arrow_drop_down),
              items: students
                  .map(
                    (student) => DropdownMenuItem<Student>(
                      value: student,
                      child: Text(
                        student.fullName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: students.isEmpty
                  ? null
                  : (value) {
                      setState(() => _selectedStudent = value);
                    },
              validator: (value) {
                if (value == null) return 'Сурагчаа сонгоно уу';
                return null;
              },
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
                      child: Text(subject, overflow: TextOverflow.ellipsis),
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
            TextFormField(
              controller: _scoreController,
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
            TextFormField(
              controller: _termController,
              decoration: const InputDecoration(
                labelText: 'Улирал',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Улирал оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: students.isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Дүн хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
