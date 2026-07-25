import 'package:flutter/material.dart';

import '../../models/teacher_note.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared latest-note summary for Student and Guardian homes.
class TeacherNoteSummaryCard extends StatelessWidget {
  const TeacherNoteSummaryCard({
    super.key,
    required this.latestNote,
    this.onTap,
  });

  final TeacherNote? latestNote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = latestNote;

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
                  const Icon(Icons.lightbulb_outline, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.item),
                  Expanded(
                    child: Text(
                      'Шинэ зөвлөгөө',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (item != null)
                    Text(
                      item.priority.label,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.item),
              Text(
                item == null ? 'Зөвлөгөө байхгүй' : item.title,
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
