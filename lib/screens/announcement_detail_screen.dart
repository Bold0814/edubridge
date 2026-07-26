import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/app_role.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Announcement body + open receipt. Teachers/admins see read stats.
class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.store,
    required this.announcement,
    this.showReceiptStats = false,
  });

  final AppStore store;
  final Announcement announcement;

  /// When true (teacher/admin), show Уншсан / Уншаагүй breakdown.
  final bool showReceiptStats;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.markAnnouncementOpened(widget.announcement.id);
    });
  }

  String _studentLabel(Student student) => student.fullName;

  String _guardianStatusLabel({
    required Student student,
    required Set<String> readGuardianIds,
  }) {
    final guardians = widget.store.guardiansForStudent(student.id);
    if (guardians.isEmpty) return '—';
    final anyRead = guardians.any(
      (g) => g.isActive && readGuardianIds.contains(g.id),
    );
    return anyRead ? 'Уншсан' : 'Уншаагүй';
  }

  String _studentStatusLabel({
    required Student student,
    required Set<String> readStudentIds,
  }) {
    return readStudentIds.contains(student.id) ? 'Уншсан' : 'Уншаагүй';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.announcement;

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final readCount = widget.store.announcementReadCount(item.id);
        final unreadCount = widget.store.announcementUnreadAudienceCount(
          item.id,
          item.className,
        );
        final receipts = widget.store.announcementReadReceiptsFor(item.id);
        final readStudentIds = <String>{
          for (final r in receipts)
            if (r.role == AppRole.student && r.studentId != null) r.studentId!,
        };
        final readGuardianIds = <String>{};
        for (final r in receipts) {
          if (r.role != AppRole.guardian) continue;
          final user = widget.store.userById(r.userAccountId);
          final gid = user?.guardianId;
          if (gid != null) readGuardianIds.add(gid);
        }
        final students = widget.store.studentsFor(item.className);

        return Scaffold(
          appBar: AppBar(title: const Text('Зарлал'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              if (item.isFeatured) ...[
                const Text('📌 Онцлох'),
                const SizedBox(height: AppSpacing.itemSm),
              ],
              Text(
                item.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.itemSm),
              Text(
                item.date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              Text(item.body, style: theme.textTheme.bodyLarge),
              if (widget.showReceiptStats) ...[
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Уншсан: $readCount  ·  Уншаагүй: $unreadCount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                if (students.isEmpty)
                  const Text('Сурагч бүртгэлгүй')
                else
                  ...students.map((student) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.item),
                      child: ListTile(
                        title: Text(_studentLabel(student)),
                        subtitle: Text(
                          'Сурагч: ${_studentStatusLabel(student: student, readStudentIds: readStudentIds)}\n'
                          'Асран хамгаалагч: ${_guardianStatusLabel(student: student, readGuardianIds: readGuardianIds)}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
              ],
            ],
          ),
        );
      },
    );
  }
}
