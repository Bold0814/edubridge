import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../navigation/app_navigation.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import '../../widgets/session_menu_button.dart';

/// Simple child picker when a guardian has multiple linked students.
class GuardianChildSelectionScreen extends StatelessWidget {
  const GuardianChildSelectionScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _select(BuildContext context, Student student) async {
    await store.setGuardianStudentId(student.id);
    if (!context.mounted) return;
    await AppNavigation.openGuardianDashboard(context, store);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final children = store.guardianPortalStudents;
        final schoolName = store.activeSchool?.name;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Миний хүүхдүүд'),
            actions: [SessionMenuButton(store: store)],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: EduBridgeLogo(size: 56)),
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    'Миний хүүхдүүд',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionSm),
                  if (children.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Танд холбоотой сурагч олдсонгүй.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: children.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.gap),
                        itemBuilder: (context, index) {
                          final child = children[index];
                          final subtitle =
                              schoolName != null && schoolName.isNotEmpty
                              ? '${child.className} анги · $schoolName'
                              : '${child.className} анги';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.card,
                              vertical: AppSpacing.itemSm,
                            ),
                            title: Text(child.fullName),
                            subtitle: Text(subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _select(context, child),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
