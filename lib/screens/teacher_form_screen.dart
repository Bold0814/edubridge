import 'package:flutter/material.dart';

import '../models/teacher.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

/// Багш нэмэх / засах.
class TeacherFormScreen extends StatefulWidget {
  const TeacherFormScreen({super.key, required this.store, this.existing});

  final AppStore store;
  final Teacher? existing;

  bool get isEditing => existing != null;

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _nameController = TextEditingController(text: t?.fullName ?? '');
    _phoneController = TextEditingController(text: t?.phone ?? '');
    _emailController = TextEditingController(text: t?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        throw ArgumentError('EMPTY');
      }

      final duplicate = widget.store.teachers.any(
        (t) => t.fullName.trim() == name && t.id != widget.existing?.id,
      );
      if (duplicate) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ижил нэртэй багш'),
            content: const Text(
              'Ийм нэртэй багш аль хэдийн байна. Үргэлжлүүлэх үү?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Болих'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Үргэлжлүүлэх'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      if (widget.isEditing) {
        await widget.store.updateTeacher(
          widget.existing!.copyWith(
            fullName: name,
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
          ),
          allowDuplicate: true,
        );
      } else {
        await widget.store.addTeacher(
          Teacher(
            id: widget.store.nextTeacherId(),
            schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
            fullName: name,
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
          ),
          allowDuplicate: true,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final message = e.message == 'EMPTY'
          ? 'Овог нэр хоосон байж болохгүй.'
          : 'Хадгалах үед алдаа гарлаа.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Багш засах' : 'Багш нэмэх'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Овог нэр'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.gap),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Утас'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.gap),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'И-мэйл'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.section),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Хадгалж байна…' : 'Хадгалах'),
          ),
        ],
      ),
    );
  }
}
