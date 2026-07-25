import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/learner_access_gate.dart';

/// Class announcements for the child's class (mark as read).
class GuardianAnnouncementsScreen extends StatelessWidget {
  const GuardianAnnouncementsScreen({
    super.key,
    required this.store,
    required this.student,
  });

  final AppStore store;
  final Student student;

  @override
  Widget build(BuildContext context) {
    return LearnerAccessGate(
      store: store,
      student: student,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.announcementsForStudentClass(student);

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Зарлал')),
            body: items.isEmpty
                ? const Center(child: Text('Зарлал байхгүй'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.item),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final read = store.isGuardianAnnouncementRead(item.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.card),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: read
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (!read)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusSm,
                                        ),
                                      ),
                                      child: const Text(
                                        'Шинэ',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.date,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.item),
                              Text(item.body),
                              if (!read) ...[
                                const SizedBox(height: AppSpacing.gap),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      store.markGuardianAnnouncementRead(
                                        item.id,
                                      );
                                    },
                                    child: const Text('Уншсан болгох'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
