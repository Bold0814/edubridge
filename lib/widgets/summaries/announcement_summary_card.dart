import 'package:flutter/material.dart';

import '../../models/announcement.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared latest-announcement summary for Student and Guardian homes.
class AnnouncementSummaryCard extends StatelessWidget {
  const AnnouncementSummaryCard({
    super.key,
    required this.latestAnnouncement,
    this.unreadCount,
    this.onTap,
  });

  final Announcement? latestAnnouncement;
  final int? unreadCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = latestAnnouncement;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.announcement,
                  ),
                  const SizedBox(width: AppSpacing.item),
                  Expanded(
                    child: Text(
                      'Сүүлийн зарлал',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (unreadCount != null && unreadCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Text(
                        'Уншаагүй: $unreadCount',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.item),
              Text(
                item == null
                    ? 'Зарлал байхгүй'
                    : '${item.title} · ${item.date}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
