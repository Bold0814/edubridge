import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';

/// Simple subject create form — owns its own controllers; never disposes AppStore.
class SubjectCreateScreen extends StatefulWidget {
  const SubjectCreateScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SubjectCreateScreen> createState() => _SubjectCreateScreenState();
}

class _SubjectCreateScreenState extends State<SubjectCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _formKey.currentState?.validate();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await widget.store.addSubject(name);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = switch (e.message) {
        'EMPTY' => 'Хичээлийн нэрээ оруулна уу',
        'DUPLICATE' => 'Ийм хичээл аль хэдийн байна.',
        _ => 'Хадгалах үед алдаа гарлаа.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хадгалах үед алдаа гарлаа.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Хичээл нэмэх')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(labelText: 'Хичээлийн нэр'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Хичээлийн нэрээ оруулна уу';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Хадгалах'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
