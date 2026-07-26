import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/edubridge_logo.dart';
import 'auth/change_password_screen.dart';
import 'home_screen.dart';
import 'school/school_selection_screen.dart';
import 'settings_screen.dart';
import 'teacher_account_screen.dart';
import 'timetable_viewer_screen.dart';

enum _TeacherWorkspaceMenuAction {
  account,
  changePassword,
  switchSchool,
  logout,
}

/// Teacher entry after school is chosen — authenticated root for teacher sessions.
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
    if (subjectId != null &&
        !store.teacherCanEditClassSubject(
          classId: classId,
          subjectId: subjectId,
        ) &&
        !store.hasAdminPermissionForActiveSchool) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStore.subjectEditDeniedMessage)),
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

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Аппаас гарах уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Үгүй'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Гарах'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      await AppNavigation.logoutToLogin(context, store);
    }
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    _TeacherWorkspaceMenuAction action,
  ) async {
    switch (action) {
      case _TeacherWorkspaceMenuAction.account:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TeacherAccountScreen(store: store),
          ),
        );
      case _TeacherWorkspaceMenuAction.changePassword:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ChangePasswordScreen(store: store, isRequired: false),
          ),
        );
      case _TeacherWorkspaceMenuAction.switchSchool:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SchoolSelectionScreen(store: store),
          ),
        );
      case _TeacherWorkspaceMenuAction.logout:
        await AppNavigation.logoutToLogin(context, store);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit(context);
      },
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final schoolName = store.activeSchool?.name ?? 'Сургууль';
          final homeroom = store.homeroomClassesForActiveTeacher();
          final teaching = store.teachingAssignmentsForActiveTeacher();

          return Scaffold(
            appBar: AppBar(
              title: const EduBridgeLogo(size: 28),
              centerTitle: true,
              automaticallyImplyLeading: false,
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
                PopupMenuButton<_TeacherWorkspaceMenuAction>(
                  tooltip: 'Цэс',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => _onMenuSelected(context, action),
                  itemBuilder: (context) {
                    final user = store.authenticatedUser;
                    final canSwitchSchool =
                        user != null &&
                        store.activeMembershipsForUser(user.id).length > 1;
                    return [
                      const PopupMenuItem(
                        value: _TeacherWorkspaceMenuAction.account,
                        child: Text('Бүртгэл'),
                      ),
                      const PopupMenuItem(
                        value: _TeacherWorkspaceMenuAction.changePassword,
                        child: Text('Нууц үг солих'),
                      ),
                      if (canSwitchSchool)
                        const PopupMenuItem(
                          value: _TeacherWorkspaceMenuAction.switchSchool,
                          child: Text('Сургууль солих'),
                        ),
                      const PopupMenuItem(
                        value: _TeacherWorkspaceMenuAction.logout,
                        child: Text('Гарах'),
                      ),
                    ];
                  },
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
                        onTap: () =>
                            _openClass(context, classId: schoolClass.id),
                      ),
                    );
                  }),
                const SizedBox(height: AppSpacing.sectionSm),
                Text('Хичээл заадаг ангиуд', style: theme.textTheme.titleSmall),
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
                        title: Text('${item.schoolClass.name} анги'),
                        subtitle: Text(item.subject.name),
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
      ),
    );
  }
}
