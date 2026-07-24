import 'package:flutter/material.dart';

import '../models/homework.dart';
import '../state/app_store.dart';
import 'homework_create_screen.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openCreateScreen(BuildContext context) async {
    await Navigator.push<Homework>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomeworkCreateScreen(className: selectedClass, store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final homeworkList = store.homeworkFor(selectedClass);
        final studentCount = store.studentsFor(selectedClass).length;

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
            Text('Сурагчдын тоо: $studentCount'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openCreateScreen(context),
              icon: const Icon(Icons.add),
              label: const Text('Шинэ даалгавар'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
            ...homeworkList.map((item) {
              final isDone = item.status == HomeworkStatus.done;
              final statusColor = isDone ? Colors.green : Colors.orange;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isDone ? Icons.assignment_turned_in : Icons.assignment,
                        color: statusColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.className,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item.subject),
                            const SizedBox(height: 4),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item.description),
                            const SizedBox(height: 4),
                            Text('Сурагчдад: $studentCount'),
                            const SizedBox(height: 8),
                            const Text('Дуусгах хугацаа:'),
                            Text(item.dueDate),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.status.label,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
