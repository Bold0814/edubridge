import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../class_list_screen.dart';
import '../student_list_screen.dart';

/// Pick a class, then manage its students (school-scoped).
class SchoolStudentsHubScreen extends StatelessWidget {
  const SchoolStudentsHubScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сурагчид')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final classes = store.classes;
          if (classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Эхлээд анги үүсгэнэ үү'),
                    const SizedBox(height: AppSpacing.gap),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassListScreen(store: store),
                          ),
                        );
                      },
                      child: const Text('Анги нэмэх'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: classes.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.item),
            itemBuilder: (context, index) {
              final className = classes[index];
              final count = store.studentsFor(className).length;
              return Card(
                child: ListTile(
                  title: Text('$className анги'),
                  subtitle: Text('$count сурагч'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentListScreen(
                          selectedClass: className,
                          store: store,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
