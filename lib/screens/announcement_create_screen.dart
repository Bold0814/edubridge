import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/app_clock.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

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

  bool get isEditing => existing != null;

  @override
  State<AnnouncementCreateScreen> createState() =>
      _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _dateController;

  bool _isFeatured = false;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _bodyController = TextEditingController(text: existing?.body ?? '');
    _isFeatured = existing?.isFeatured ?? false;
    _selectedDate = _parseExistingDate(existing?.date) ?? AppClock.today();
    _dateController = TextEditingController(
      text: existing?.date.trim().isNotEmpty == true
          ? existing!.date
          : _formatMongolianDate(_selectedDate),
    );
  }

  DateTime? _parseExistingDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(
      r'(\d{4})\s*оны\s*(\d{1,2})\s*сарын\s*(\d{1,2})',
    ).firstMatch(raw);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatMongolianDate(DateTime date) {
    return AppClock.mongolianLabel(date);
  }

  Future<void> _pickDate() async {
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
      _dateController.text = _formatMongolianDate(picked);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final announcement = Announcement(
        id: widget.existing?.id ?? widget.store.nextAnnouncementId(),
        schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
        className: widget.className,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        date: _dateController.text.trim(),
        isFeatured: _isFeatured,
      );

      if (widget.isEditing) {
        await widget.store.updateAnnouncement(announcement);
      } else {
        await widget.store.addAnnouncement(announcement);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Зарлал амжилттай хадгалагдлаа.')),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Зарлал засах' : 'Шинэ зарлал'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              '${widget.className} анги',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.gap),
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
            const SizedBox(height: AppSpacing.gap),
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
            const SizedBox(height: AppSpacing.itemSm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Онцлох зарлал'),
              value: _isFeatured,
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _isFeatured = value);
                    },
            ),
            const SizedBox(height: AppSpacing.itemSm),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _saving ? null : _pickDate,
              decoration: InputDecoration(
                labelText: 'Огноо',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _saving ? null : _pickDate,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Огноо сонгоно уу';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.section),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Зарлал хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
