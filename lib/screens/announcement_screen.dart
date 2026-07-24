import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../state/app_store.dart';
import 'announcement_create_screen.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openCreateScreen(BuildContext context) async {
    await Navigator.push<Announcement>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AnnouncementCreateScreen(className: selectedClass, store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final announcements = store.announcementsFor(selectedClass);

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
              onPressed: () => _openCreateScreen(context),
              icon: const Icon(Icons.add),
              label: const Text('Шинэ зарлал'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
            ...announcements.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.campaign, color: Colors.blue),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.isFeatured) ...[
                              const Text('📌'),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              item.className,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item.date),
                            const SizedBox(height: 4),
                            Text(
                              item.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
