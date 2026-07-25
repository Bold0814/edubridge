import 'package:flutter/material.dart';

import '../../models/school.dart';
import '../../navigation/app_navigation.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';

/// Pick a school when the authenticated user has multiple active memberships.
class SchoolSelectionScreen extends StatelessWidget {
  const SchoolSelectionScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = store.authenticatedUser;
    final memberships = user == null
        ? const <UserSchoolMembership>[]
        : store.activeMembershipsForUser(user.id);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.gap),
              const Center(child: EduBridgeLogo(size: 64)),
              const SizedBox(height: AppSpacing.gap),
              Text(
                'Сургуулиа сонгоно уу',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Expanded(
                child: ListView.separated(
                  itemCount: memberships.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.gap),
                  itemBuilder: (context, index) {
                    final membership = memberships[index];
                    School? school;
                    for (final item in store.schools) {
                      if (item.id == membership.schoolId) {
                        school = item;
                        break;
                      }
                    }
                    final name = school?.name ?? membership.schoolId;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.card,
                          vertical: AppSpacing.itemSm,
                        ),
                        title: Text(name),
                        subtitle: Text(membership.role.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          AppNavigation.afterSchoolSelected(
                            context,
                            store,
                            membership,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
