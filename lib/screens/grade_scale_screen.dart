import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Read-only display of the current 0–100 / A–F letter scale.
class GradeScaleScreen extends StatelessWidget {
  const GradeScaleScreen({super.key});

  static const _rows = [
    ('95–100', 'A+'),
    ('90–94', 'A'),
    ('85–89', 'B+'),
    ('80–84', 'B'),
    ('75–79', 'C+'),
    ('70–74', 'C'),
    ('60–69', 'D'),
    ('0–59', 'F'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Үнэлгээний систем'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            'Одоогийн систем: 0–100 оноо, A–F үсэг',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.itemSm),
          Text(
            'Энэ спринтэд зөвхөн харуулна. Тооцооллын логик өөрчлөгдөөгүй.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionSm),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _rows.length; i++) ...[
                  ListTile(
                    title: Text(_rows[i].$1),
                    trailing: Text(
                      _rows[i].$2,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.grade,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (i < _rows.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
