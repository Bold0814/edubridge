import 'package:flutter/material.dart';

import '../models/homework.dart';
import '../state/app_store.dart';

class HomeworkCreateScreen extends StatefulWidget {
  const HomeworkCreateScreen({
    super.key,
    required this.className,
    required this.store,
  });

  final String className;
  final AppStore store;

  @override
  State<HomeworkCreateScreen> createState() => _HomeworkCreateScreenState();
}

class _HomeworkCreateScreenState extends State<HomeworkCreateScreen> {
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
    _selectedDate = DateTime.now();
    _dueDateController.text = _formatMongolianDate(_selectedDate);
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
    return '${date.year} оны ${date.month} сарын ${date.day}';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final homework = Homework(
      className: widget.className,
      subject: _selectedSubject!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDateController.text.trim(),
      status: HomeworkStatus.pending,
    );

    widget.store.addHomework(homework);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Даалгавар амжилттай хадгалагдлаа.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, homework);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Шинэ даалгавар'), centerTitle: true),
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
