import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/homework.dart';
import '../services/app_clock.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';

class HomeworkCreateScreen extends StatefulWidget {
  const HomeworkCreateScreen({
    super.key,
    required this.className,
    required this.store,
    this.existing,
    this.initialSubject,
    this.lockSubject = false,
  });

  final String className;
  final AppStore store;
  final Homework? existing;
  final String? initialSubject;

  /// When true, subject is fixed (active teaching subject) and not re-selected.
  final bool lockSubject;

  @override
  State<HomeworkCreateScreen> createState() => _HomeworkCreateScreenState();
}

class _HomeworkCreateScreenState extends State<HomeworkCreateScreen> {
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();

  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  String? _selectedSubject;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description;
      _dueDateController.text = existing.dueDate;
      final parsedDate = AttendanceRecord.tryParseCalendarDate(
        existing.dueDate,
      );
      _selectedDate = parsedDate ?? AppClock.today();
      _selectedSubject = existing.subject;
    } else {
      _selectedDate = AppClock.today();
      _dueDateController.text = _formatMongolianDate(_selectedDate);
      final initial = widget.initialSubject;
      if (initial != null &&
          (_subjects.contains(initial) || widget.lockSubject)) {
        _selectedSubject = initial;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  String _formatMongolianDate(DateTime date) {
    return AppClock.mongolianLabel(date);
  }

  Future<void> _pickDueDate() async {
    final now = AppClock.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _dueDateController.text = _formatMongolianDate(picked);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final subject = _selectedSubject?.trim();
    if (subject == null || subject.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Хичээлээ сонгоно уу')));
      return;
    }

    final existing = widget.existing;
    final homework = Homework(
      id: existing?.id ?? widget.store.nextHomeworkId(),
      className: widget.className,
      subject: subject,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDateController.text.trim(),
      status: existing?.status ?? HomeworkStatus.pending,
    );

    if (existing != null) {
      await widget.store.updateHomework(homework);
    } else {
      await widget.store.addHomework(homework);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Даалгавар амжилттай хадгалагдлаа.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context, homework);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Даалгавар засах' : 'Шинэ даалгавар',
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
            if (widget.lockSubject && _selectedSubject != null)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Хичээл',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedSubject!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            else
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
                  _titleFocusNode.requestFocus();
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
              controller: _titleController,
              focusNode: _titleFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                _descriptionFocusNode.requestFocus();
              },
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
              controller: _dueDateController,
              readOnly: true,
              onTap: _pickDueDate,
              decoration: InputDecoration(
                labelText: 'Дуусах хугацаа',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDueDate,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Дуусах хугацаа сонгоно уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              textInputAction: TextInputAction.done,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Тайлбар',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Тайлбар оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Даалгавар хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
