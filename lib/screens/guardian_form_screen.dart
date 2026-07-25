import 'package:flutter/material.dart';

import '../models/guardian.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

class GuardianFormScreen extends StatefulWidget {
  const GuardianFormScreen({super.key, required this.store, this.existing});

  final AppStore store;
  final Guardian? existing;

  bool get isEditing => existing != null;

  @override
  State<GuardianFormScreen> createState() => _GuardianFormScreenState();
}

class _GuardianFormScreenState extends State<GuardianFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nameController = TextEditingController(text: g?.fullName ?? '');
    _phoneController = TextEditingController(text: g?.phone ?? '');
    _emailController = TextEditingController(text: g?.email ?? '');
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
      if (widget.isEditing) {
        await widget.store.updateGuardian(
          widget.existing!.copyWith(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
          ),
        );
      } else {
        await widget.store.addGuardian(
          Guardian(
            id: widget.store.nextGuardianId(),
            schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on ArgumentError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Овог нэр хоосон байж болохгүй.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Асран хамгаалагч засах'
              : 'Асран хамгаалагч нэмэх',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Овог нэр'),
          ),
          const SizedBox(height: AppSpacing.gap),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Утас'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.gap),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'И-мэйл'),
            keyboardType: TextInputType.emailAddress,
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
