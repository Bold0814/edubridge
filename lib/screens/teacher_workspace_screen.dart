import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/edubridge_logo.dart';
import '../widgets/session_menu_button.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'timetable_viewer_screen.dart';

/// Teacher entry after school is chosen — pick homeroom or teaching context.
class TeacherWorkspaceScreen extends StatelessWidget {
  const TeacherWorkspaceScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _openClass(
    BuildContext context, {
    required String classId,
    int? subjectId,
  }) async {
    if (!store.teacherCanAccessClass(classId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ ангид хандах эрхгүй байна.')),
      );
      return;
    }
    await store.setTeacherWorkspace(classId: classId, subjectId: subjectId);
    if (subjectId != null) {
      final subject = store.subjectById(subjectId);
      if (subject != null) {
        store.setJournalSubject(classId, subject.name);
      }
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(selectedClass: classId, store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final schoolName = store.activeSchool?.name ?? 'Сургууль';
        final homeroom = store.homeroomClassesForActiveTeacher();
        final teaching = store.teachingAssignmentsForActiveTeacher();

        return Scaffold(
          appBar: AppBar(
            title: const EduBridgeLogo(size: 28),
            centerTitle: true,
            leading: Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Буцах',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            actions: [
              if (store.hasAdminPermissionForActiveSchool)
                IconButton(
                  tooltip: 'Тохиргоо',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(store: store),
                      ),
                    );
                  },
                ),
              SessionMenuButton(
                store: store,
                showChangeContext: store.hasAdminPermissionForActiveSchool,
                openAdminHomeOnChangeContext: true,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(schoolName, style: theme.textTheme.titleMedium),
              Text(
                'Багшийн ажлын хэсэг',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Миний хуваарь'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TimetableViewerScreen(
                          store: store,
                          title: 'Миний хуваарь',
                          mode: TimetableViewerMode.teacher,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Text('Анги удирдсан', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.item),
              if (homeroom.isEmpty)
                Text(
                  'Анги байхгүй',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                ...homeroom.map((schoolClass) {
                  return Card(
                    child: ListTile(
                      title: Text('${schoolClass.name} анги'),
                      subtitle: const Text('Ангийн багш'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openClass(context, classId: schoolClass.id),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.sectionSm),
              Text('Хичээл заадаг', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.item),
              if (teaching.isEmpty)
                Text(
                  'Хичээл байхгүй',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                ...teaching.map((item) {
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${item.schoolClass.name} · ${item.subject.name}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openClass(
                        context,
                        classId: item.schoolClass.id,
                        subjectId: item.subject.id,
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
