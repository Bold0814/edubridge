import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../state/app_store.dart';

class AnnouncementCreateScreen extends StatefulWidget {
  const AnnouncementCreateScreen({
    super.key,
    required this.className,
    required this.store,
    this.existing,
  });

  final String className;
  final AppStore store;
  final Announcement? existing;

  @override
  State<AnnouncementCreateScreen> createState() =>
      _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _dateController = TextEditingController();

  bool _isFeatured = false;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = _formatMongolianDate(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatMongolianDate(DateTime date) {
    return '${date.year} оны ${date.month} сарын ${date.day}';
  }

  Future<void> _pickDate() async {
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
      _dateController.text = _formatMongolianDate(picked);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final announcement = Announcement(
      id: widget.existing?.id ?? widget.store.nextAnnouncementId(),
      schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
      className: widget.className,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      date: _dateController.text.trim(),
      isFeatured: _isFeatured,
    );

    if (widget.existing != null) {
      widget.store.updateAnnouncement(announcement);
    } else {
      widget.store.addAnnouncement(announcement);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Зарлал амжилттай хадгалагдлаа.')),
    );
    Navigator.pop(context, announcement);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Шинэ зарлал'), centerTitle: true),
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
              controller: _bodyController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Зарлал',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Зарлал оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Онцлох зарлал'),
              value: _isFeatured,
              onChanged: (value) {
                setState(() => _isFeatured = value);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'Огноо',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Огноо сонгоно уу';
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
              child: const Text('Зарлал хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
