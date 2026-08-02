import 'package:firebase_core/firebase_core.dart';
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

  String _messageForError(Object error) {
    if (error is PermissionDeniedException) {
      return 'Танд энэ хичээлийг нэмэх эрх алга. Админ бүртгэлээ шалгана уу.';
    }
    if (error is ArgumentError) {
      return switch (error.message) {
        'EMPTY' => 'Хичээлийн нэрээ оруулна уу',
        'DUPLICATE' => 'Ийм нэртэй хичээл өмнө нь бүртгэгдсэн байна.',
        'UNAUTHENTICATED' =>
          'Нэвтрэх хугацаа дууссан байна. Дахин нэвтэрнэ үү.',
        _ => 'Хадгалах үед алдаа гарлаа.',
      };
    }
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'permission-denied') {
        return 'Танд энэ хичээлийг нэмэх эрх алга. Админ бүртгэлээ шалгана уу.';
      }
      if (code == 'unauthenticated') {
        return 'Нэвтрэх хугацаа дууссан байна. Дахин нэвтэрнэ үү.';
      }
    }
    return 'Хадгалах үед алдаа гарлаа.';
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
    } catch (e) {
      debugPrint(
        'SubjectCreateScreen save error=$e '
        'schoolId=${widget.store.activeSchoolId} '
        'authUid=${widget.store.authenticatedUser?.authUid}',
      );
      if (e is FirebaseException) {
        debugPrint(
          'SubjectCreateScreen FirebaseException code=${e.code} '
          'message=${e.message}',
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageForError(e))));
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
