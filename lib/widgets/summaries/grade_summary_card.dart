import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared grade average summary for Student and Guardian homes.
class GradeSummaryCard extends StatelessWidget {
  const GradeSummaryCard({super.key, required this.averageGrade, this.onTap});

  final double? averageGrade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = averageGrade == null ? '—' : averageGrade!.toStringAsFixed(1);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Row(
            children: [
              const Icon(Icons.grade_outlined, color: AppColors.grade),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Text('Дундаж дүн', style: theme.textTheme.titleSmall),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.grade,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
