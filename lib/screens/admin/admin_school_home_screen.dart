import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin_permission_gate.dart';
import '../../widgets/edubridge_logo.dart';
import '../../widgets/session_menu_button.dart';
import '../class_list_screen.dart';
import '../onboarding/school_setup_screen.dart';
import '../settings_screen.dart';
import '../subjects_settings_screen.dart';
import '../teacher_list_screen.dart';
import 'school_students_hub_screen.dart';

/// Simple school administration home for the active school.
class AdminSchoolHomeScreen extends StatelessWidget {
  const AdminSchoolHomeScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schoolName = store.activeSchool?.name ?? 'Сургууль';

        return AdminPermissionGate(
          store: store,
          child: Scaffold(
            appBar: AppBar(
              title: const EduBridgeLogo(size: 28),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Бэлтгэл',
                  icon: const Icon(Icons.checklist_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SchoolSetupScreen(store: store),
                      ),
                    );
                  },
                ),
                SessionMenuButton(store: store, showChangeContext: false),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Text(schoolName, style: theme.textTheme.titleLarge),
                Text(
                  'Сургуулийн удирдлага',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionSm),
                _ActionTile(
                  title: 'Багш нар',
                  onTap: () => _open(context, TeacherListScreen(store: store)),
                ),
                _ActionTile(
                  title: 'Ангиуд',
                  onTap: () => _open(context, ClassListScreen(store: store)),
                ),
                _ActionTile(
                  title: 'Хичээлүүд',
                  onTap: () =>
                      _open(context, SubjectsSettingsScreen(store: store)),
                ),
                _ActionTile(
                  title: 'Сурагчид',
                  onTap: () =>
                      _open(context, SchoolStudentsHubScreen(store: store)),
                ),
                _ActionTile(
                  title: 'Тохиргоо',
                  onTap: () => _open(context, SettingsScreen(store: store)),
                ),
                if (store.hasTeacherWorkspaceAccess) ...[
                  const SizedBox(height: AppSpacing.sectionSm),
                  TextButton(
                    onPressed: () {
                      AppNavigation.openTeacherWorkspace(context, store);
                    },
                    child: const Text('Багшийн ажлын хэсэг'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
