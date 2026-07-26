import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'class_create_screen.dart';
import 'teacher_list_screen.dart';

/// Manage classes for the active school.
class ClassListScreen extends StatelessWidget {
  const ClassListScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _addClass(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => ClassCreateScreen(store: store)),
    );
    if (!context.mounted) return;
    if (created == true) {
      // store already updated by addSchoolClass
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
