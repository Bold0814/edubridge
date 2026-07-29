import 'package:flutter/material.dart';

import '../models/teacher_note.dart';
import '../services/app_clock.dart';
import '../state/app_store.dart';

class TeacherNoteFormScreen extends StatefulWidget {
  const TeacherNoteFormScreen({
    super.key,
    required this.className,
    required this.store,
    this.existing,
  });

  final String className;
  final AppStore store;
  final TeacherNote? existing;

  @override
  State<TeacherNoteFormScreen> createState() => _TeacherNoteFormScreenState();
}

class _TeacherNoteFormScreenState extends State<TeacherNoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String? _studentId;
  int? _subjectId;
  NotePriority _priority = NotePriority.normal;
  bool _visibleToStudent = true;
  bool _visibleToGuardian = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final students = widget.store.studentsFor(widget.className);
    if (existing != null) {
      _titleController.text = existing.title;
      _messageController.text = existing.message;
      _studentId = existing.studentId;
      _subjectId = existing.subjectId;
      _priority = existing.priority;
      _visibleToStudent = existing.isVisibleToStudent;
      _visibleToGuardian = existing.isVisibleToGuardian;
    } else if (students.isNotEmpty) {
      _studentId = students.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final studentId = _studentId;
    if (studentId == null) {
      setState(() => _error = 'Сурагч сонгоно уу');
      return;
    }

    final teacherId = widget.store.activeContext.teacherId;
    if (teacherId == null || teacherId.isEmpty) {
      setState(
        () => _error = 'Багш олдсонгүй. Эхлээд багш бүртгэж, ангид холбоно уу.',
      );
      return;
    }

    setState(() => _error = null);

    final existing = widget.existing;
    final note = TeacherNote(
      id: existing?.id ?? widget.store.nextTeacherNoteId(),
      studentId: studentId,
      teacherId: existing?.teacherId ?? teacherId,
      subjectId: _subjectId,
      createdAt: existing?.createdAt ?? AppClock.now().toIso8601String(),
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      priority: _priority,
      isVisibleToGuardian: _visibleToGuardian,
      isVisibleToStudent: _visibleToStudent,
      schoolId: existing?.schoolId ?? widget.store.activeSchoolId,
      classId: widget.className,
      createdByUid: existing?.createdByUid,
    );

    try {
      if (existing != null) {
        await widget.store.updateTeacherNote(note);
      } else {
        await widget.store.addTeacherNote(note);
      }
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Зөвлөгөө амжилттай хадгалагдлаа.')),
    );
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.store.studentsFor(widget.className);
    final subjects = widget.store.activeSubjects;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Зөвлөгөө засах' : 'Шинэ зөвлөгөө',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.className} анги',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _studentId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Сурагч',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final student in students)
                  DropdownMenuItem(
                    value: student.id,
                    child: Text(
                      student.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _studentId = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Сурагч сонгоно уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Хичээл (заавал биш)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Сонгоогүй'),
                ),
                for (final subject in subjects)
                  DropdownMenuItem<int?>(
                    value: subject.id,
                    child: Text(subject.name),
                  ),
              ],
              onChanged: (value) => setState(() => _subjectId = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Гарчиг',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Гарчиг оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Зөвлөгөө',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Зөвлөгөө оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NotePriority>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Ач холбогдол',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final priority in NotePriority.values)
                  DropdownMenuItem(
                    value: priority,
                    child: Text(priority.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Сурагчид харагдана'),
              value: _visibleToStudent,
              onChanged: (value) {
                setState(() => _visibleToStudent = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Асран хамгаалагчид харагдана'),
              value: _visibleToGuardian,
              onChanged: (value) {
                setState(() => _visibleToGuardian = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Зөвлөгөө хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
