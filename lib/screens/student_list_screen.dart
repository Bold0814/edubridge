import 'package:flutter/material.dart';

import '../models/student.dart';
import '../state/app_store.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openForm(BuildContext context, {Student? student}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentFormScreen(
          className: selectedClass,
          store: store,
          student: student,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Сурагч устгах'),
          content: Text('${student.fullName}-ийг устгах уу?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Устгах'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    store.deleteStudent(selectedClass, student.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Сурагч устгагдлаа.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Сурагчид'), centerTitle: true),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final students = store.studentsFor(selectedClass);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$selectedClass анги',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text('Нийт сурагч: ${students.length}'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Сурагч нэмэх'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Энэ ангид сурагч байхгүй байна.')),
                )
              else
                ...students.map((student) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Icon(
                        student.gender == StudentGender.male
                            ? Icons.man
                            : Icons.woman,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        student.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(student.gender.label),
                          if (student.register != null)
                            Text('Регистр: ${student.register}'),
                          if (student.phone != null)
                            Text('Утас: ${student.phone}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Засах',
                            onPressed: () =>
                                _openForm(context, student: student),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Устгах',
                            onPressed: () => _confirmDelete(context, student),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
