import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import '../../widgets/session_menu_button.dart';
import '../admin/admin_school_home_screen.dart';
import '../admin/school_students_hub_screen.dart';
import '../class_list_screen.dart';
import '../subjects_settings_screen.dart';
import '../teacher_list_screen.dart';

/// First-time school setup — four essentials only.
class SchoolSetupScreen extends StatelessWidget {
  const SchoolSetupScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _enterWorkspace(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => AdminSchoolHomeScreen(store: store),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schoolName = store.activeSchool?.name ?? 'Сургууль';
        final hasTeachers = store.activeTeachers.isNotEmpty;
        final hasClasses = store.classes.isNotEmpty;
        final hasSubjects = store.activeSubjects.isNotEmpty;
        final hasStudents = store.studentsInActiveSchool.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Сургуулиа бэлтгэх'),
            actions: [
              SessionMenuButton(store: store, showChangeContext: false),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: EduBridgeLogo(size: 48)),
                const SizedBox(height: AppSpacing.gap),
                Text(
                  schoolName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Сургуулиа бэлтгэх',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionSm),
                _SetupTile(
                  index: 1,
                  title: 'Багш нар',
                  done: hasTeachers,
                  onTap: () => _open(context, TeacherListScreen(store: store)),
                ),
                _SetupTile(
                  index: 2,
                  title: 'Ангиуд',
                  done: hasClasses,
                  onTap: () => _open(context, ClassListScreen(store: store)),
                ),
                _SetupTile(
                  index: 3,
                  title: 'Хичээлүүд',
                  done: hasSubjects,
                  onTap: () =>
                      _open(context, SubjectsSettingsScreen(store: store)),
                ),
                _SetupTile(
                  index: 4,
                  title: 'Сурагчид',
                  done: hasStudents,
                  onTap: () {
                    if (!hasClasses) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Эхлээд анги үүсгэнэ үү')),
                      );
                      return;
                    }
                    _open(context, SchoolStudentsHubScreen(store: store));
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                FilledButton(
                  onPressed: () => _enterWorkspace(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Ажлын хэсэг рүү орох'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.index,
    required this.title,
    required this.onTap,
    this.done = false,
  });

  final int index;
  final String title;
  final VoidCallback onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: done ? const Icon(Icons.check, size: 18) : Text('$index'),
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
