import 'package:flutter/material.dart';

import '../../models/homework.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared due-soon homework summary for Student and Guardian homes.
class HomeworkSummaryCard extends StatelessWidget {
  const HomeworkSummaryCard({
    super.key,
    required this.dueSoonHomework,
    this.onTap,
  });

  final List<Homework> dueSoonHomework;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = dueSoonHomework.isEmpty ? null : dueSoonHomework.first;

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
                    Icons.assignment_outlined,
                    color: AppColors.homework,
                  ),
                  const SizedBox(width: AppSpacing.item),
                  Expanded(
                    child: Text(
                      'Хугацаа дөхсөн даалгавар',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${dueSoonHomework.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.item),
              Text(
                first == null
                    ? 'Хүлээгдэж буй даалгавар байхгүй'
                    : '${first.subject}: ${first.title} · ${first.dueDate}',
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
