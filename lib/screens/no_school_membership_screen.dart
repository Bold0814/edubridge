import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/edubridge_logo.dart';

/// Shown when the signed-in user has no active school membership.
class NoSchoolMembershipScreen extends StatelessWidget {
  const NoSchoolMembershipScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.section),
              const EduBridgeLogo(size: 72),
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Сургууль холбоогүй',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              Text(
                'Танд хамаарах идэвхтэй сургууль олдсонгүй.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => AppNavigation.logoutToLogin(context, store),
                child: const Text('Гарах'),
              ),
              const SizedBox(height: AppSpacing.section),
            ],
          ),
        ),
      ),
    );
  }
}
