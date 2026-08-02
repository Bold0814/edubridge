import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'subject_create_screen.dart';

/// CRUD UI for the shared subject catalog stored in SQLite.
class SubjectsSettingsScreen extends StatelessWidget {
  const SubjectsSettingsScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _add(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SubjectCreateScreen(store: store)),
    );
    if (!context.mounted) return;
    if (created == true) {
      await store.reloadSubjectsForActiveSchool();
    }
  }

  Future<void> _edit(BuildContext context, String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _SubjectNameDialog(title: 'Хичээл засах', initial: current),
    );
    if (name == null || !context.mounted) return;
    try {
      await store.renameSubject(current, name);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      _showError(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Идэвхгүй болгох'),
        content: const Text(
          'Энэ хичээлийг идэвхгүй болгох уу? Холбоотой тохиргоо байвал бүрэн устгахгүй.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Идэвхгүй болгох'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await store.deleteSubject(name);
  }

  void _showError(BuildContext context, String? code) {
    final message = switch (code) {
      'EMPTY' => 'Хичээлийн нэрээ оруулна уу',
      'DUPLICATE' => 'Ийм нэртэй хичээл өмнө нь бүртгэгдсэн байна.',
      'UNAUTHENTICATED' => 'Нэвтрэх хугацаа дууссан байна. Дахин нэвтэрнэ үү.',
      _ => 'Хадгалах үед алдаа гарлаа.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Хичээлүүд'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        tooltip: 'Нэмэх',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final subjects = store.allSubjects;
          if (subjects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Хичээл үүсгээгүй байна'),
                    const SizedBox(height: AppSpacing.gap),
                    FilledButton(
                      onPressed: () => _add(context),
                      child: const Text('Хичээл нэмэх'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.page,
              AppSpacing.page,
              88,
            ),
            itemCount: subjects.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.item),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                child: ListTile(
                  title: Text(subject.name),
                  subtitle: subject.isActive ? null : const Text('Идэвхгүй'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Засах',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, subject.name),
                      ),
                      if (subject.isActive)
                        IconButton(
                          tooltip: 'Идэвхгүй болгох',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, subject.name),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dialog that owns its TextEditingController and disposes it in [dispose].
class _SubjectNameDialog extends StatefulWidget {
  const _SubjectNameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_SubjectNameDialog> createState() => _SubjectNameDialogState();
}

class _SubjectNameDialogState extends State<_SubjectNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Хичээлийн нэр'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Болих'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Хадгалах'),
        ),
      ],
    );
  }
}
