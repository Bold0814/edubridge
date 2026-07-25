import 'package:flutter/material.dart';

import '../models/teacher.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'teacher_form_screen.dart';

/// Багш нарын жагсаалт.
class TeacherListScreen extends StatelessWidget {
  const TeacherListScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {Teacher? teacher}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TeacherFormScreen(store: store, existing: teacher),
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, Teacher teacher) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Идэвхгүй болгох'),
        content: Text(
          '"${teacher.fullName}" багшийг идэвхгүй болгох уу?\n'
          'Анги, хичээлтэй холбоотой бол устгахгүй.',
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
    await store.deactivateTeacher(teacher.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Багш идэвхгүй боллоо')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Багш нар')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Багш нэмэх',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final teachers = store.teachers;
          if (teachers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Багш бүртгээгүй байна'),
                    const SizedBox(height: AppSpacing.gap),
                    FilledButton(
                      onPressed: () => _openForm(context),
                      child: const Text('Багш нэмэх'),
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
            itemCount: teachers.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.item),
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return Card(
                child: ListTile(
                  title: Text(teacher.fullName),
                  subtitle: Text(
                    [
                      if (teacher.phone.isNotEmpty) teacher.phone,
                      if (teacher.email.isNotEmpty) teacher.email,
                      if (!teacher.isActive) 'Идэвхгүй',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Засах',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openForm(context, teacher: teacher),
                      ),
                      if (teacher.isActive)
                        IconButton(
                          tooltip: 'Идэвхгүй болгох',
                          icon: const Icon(Icons.person_off_outlined),
                          onPressed: () => _deactivate(context, teacher),
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
