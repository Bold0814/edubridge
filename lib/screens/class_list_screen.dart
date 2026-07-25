import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'teacher_form_screen.dart';
import 'teacher_list_screen.dart';

/// Manage classes for the active school.
class ClassListScreen extends StatelessWidget {
  const ClassListScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _addClass(BuildContext context) async {
    final teachers = store.activeTeachers;
    final nameController = TextEditingController();
    String? homeroomTeacherId;

    final result = await showDialog<Object>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Анги нэмэх'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Ангийн нэр',
                        hintText: 'ж: 6А',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (teachers.isEmpty) ...[
                      const Text('Багш бүртгээгүй байна'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, 'open_teacher');
                        },
                        child: const Text('Багш нэмэх'),
                      ),
                    ] else
                      DropdownButtonFormField<String?>(
                        initialValue: homeroomTeacherId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Анги удирдсан багш',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Сонгохгүй'),
                          ),
                          for (final teacher in teachers)
                            DropdownMenuItem<String?>(
                              value: teacher.id,
                              child: Text(
                                teacher.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setLocal(() => homeroomTeacherId = value);
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Болих'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, (
                      name: nameController.text,
                      teacherId: homeroomTeacherId,
                    ));
                  },
                  child: const Text('Нэмэх'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (!context.mounted) return;

    if (result == 'open_teacher') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherFormScreen(store: store),
        ),
      );
      return;
    }
    if (result is! ({String name, String? teacherId})) return;

    try {
      await store.addSchoolClass(
        name: result.name,
        homeroomTeacherId: result.teacherId,
      );
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      final message = switch (e.message) {
        'EMPTY_CLASS' => 'Ангийн нэрээ оруулна уу',
        'DUPLICATE_CLASS' => 'Ийм анги аль хэдийн байна',
        _ => 'Анги нэмэхэд алдаа гарлаа',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ангиуд')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addClass(context),
        tooltip: 'Анги нэмэх',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final classes = store.schoolClassesForActiveSchool;
          if (classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Анги үүсгээгүй байна'),
                    const SizedBox(height: AppSpacing.gap),
                    FilledButton(
                      onPressed: () => _addClass(context),
                      child: const Text('Анги нэмэх'),
                    ),
                    if (store.activeTeachers.isEmpty) ...[
                      const SizedBox(height: AppSpacing.gap),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TeacherListScreen(store: store),
                            ),
                          );
                        },
                        child: const Text('Багш нэмэх'),
                      ),
                    ],
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
            itemCount: classes.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.item),
            itemBuilder: (context, index) {
              final schoolClass = classes[index];
              final count = store.studentsFor(schoolClass.name).length;
              final home = store.homeroomTeacherForClass(schoolClass.id);
              return Card(
                child: ListTile(
                  title: Text('${schoolClass.name} анги'),
                  subtitle: Text(
                    home == null
                        ? '$count сурагч · Анги удирдсан багш сонгоогүй'
                        : '$count сурагч · Анги удирдсан багш: ${home.fullName}',
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
