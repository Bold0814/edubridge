import 'package:flutter/material.dart';

import '../models/grade.dart';
import '../state/app_store.dart';
import 'bulk_grade_entry_screen.dart';
import 'grade_create_screen.dart';

class GradeScreen extends StatelessWidget {
  const GradeScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openCreateScreen(BuildContext context) async {
    await Navigator.push<Grade>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GradeCreateScreen(className: selectedClass, store: store),
      ),
    );
  }

  Future<void> _openBulkEntryScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BulkGradeEntryScreen(selectedClass: selectedClass, store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final grades = store.gradesFor(selectedClass);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$selectedClass анги',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openBulkEntryScreen(context),
              icon: const Icon(Icons.groups),
              label: const Text('Ангийн дүн оруулах'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openCreateScreen(context),
              icon: const Icon(Icons.add),
              label: const Text('Дүн оруулах'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
            ...grades.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.grade, color: Colors.purple),
                  title: Text(
                    item.subject,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${item.studentName}\n${item.term}'),
                  isThreeLine: true,
                  trailing: Text(
                    item.scoreWithLetter,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
