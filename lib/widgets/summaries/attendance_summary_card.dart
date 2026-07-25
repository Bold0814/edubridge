import 'package:flutter/material.dart';

import '../../models/attendance_record.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Shared attendance summary used by Student and Guardian homes.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    super.key,
    required this.todaysStatus,
    this.presentCount,
    this.lateCount,
    this.absentCount,
    this.showBriefStats = false,
    this.onTap,
  });

  final AttendanceStatus? todaysStatus;
  final int? presentCount;
  final int? lateCount;
  final int? absentCount;
  final bool showBriefStats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = todaysStatus?.label ?? 'Бүртгэгдээгүй';

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
                  Icon(Icons.fact_check_outlined, color: AppColors.present),
                  const SizedBox(width: AppSpacing.item),
                  Expanded(
                    child: Text(
                      'Өнөөдрийн ирц',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  StatusBadge(
                    label: statusLabel,
                    color: todaysStatus?.color ?? AppColors.onSurfaceVariant,
                    compact: true,
                  ),
                ],
              ),
              if (showBriefStats) ...[
                const SizedBox(height: AppSpacing.gap),
                Text(
                  'Ирсэн: ${presentCount ?? 0} · '
                  'Хоцорсон: ${lateCount ?? 0} · '
                  'Тасалсан: ${absentCount ?? 0}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
