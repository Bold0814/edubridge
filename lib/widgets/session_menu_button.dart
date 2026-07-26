import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../navigation/app_navigation.dart';
import '../screens/admin/admin_school_home_screen.dart';
import '../screens/guardian/guardian_child_selection_screen.dart';
import '../screens/school/school_selection_screen.dart';
import '../screens/teacher_workspace_screen.dart';
import '../state/app_store.dart';

enum _SessionMenuAction { changeContext, switchSchool, schoolSetup, logout }

/// Compact profile menu: context switch, school switch, logout.
class SessionMenuButton extends StatelessWidget {
  const SessionMenuButton({
    super.key,
    required this.store,
    this.showChangeContext = true,
    this.openAdminHomeOnChangeContext = false,
    this.showSchoolSetupProgress = false,
    this.onOpenSchoolSetup,
  });

  final AppStore store;
  final bool showChangeContext;

  /// When true, “Сонголт солих” returns to [AdminSchoolHomeScreen]
  /// (admin + teacher switching from the teacher workspace).
  final bool openAdminHomeOnChangeContext;

  /// Admin-only: show “Бэлтгэлийн явц” in the overflow menu.
  final bool showSchoolSetupProgress;

  final VoidCallback? onOpenSchoolSetup;

  Future<void> _onSelected(
    BuildContext context,
    _SessionMenuAction action,
  ) async {
    switch (action) {
      case _SessionMenuAction.changeContext:
        await _changeContext(context);
      case _SessionMenuAction.switchSchool:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SchoolSelectionScreen(store: store),
          ),
        );
      case _SessionMenuAction.schoolSetup:
        onOpenSchoolSetup?.call();
      case _SessionMenuAction.logout:
        await AppNavigation.logoutToLogin(context, store);
    }
  }

  Future<void> _changeContext(BuildContext context) async {
    if (openAdminHomeOnChangeContext &&
        store.hasAdminPermissionForActiveSchool) {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => AdminSchoolHomeScreen(store: store),
        ),
        (route) => false,
      );
      return;
    }

    final role = store.activeContext.role ?? store.selectedDevelopmentRole;
    if (role == AppRole.teacher) {
      store.clearSchoolScopedSelections();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TeacherWorkspaceScreen(store: store),
        ),
        (route) => false,
      );
      return;
    }
    if (role == AppRole.guardian) {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => GuardianChildSelectionScreen(store: store),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = store.authenticatedUser;
    final canSwitchSchool =
        user != null && store.activeMembershipsForUser(user.id).length > 1;
    final role = store.activeContext.role ?? store.selectedDevelopmentRole;
    final canChangeContext =
        showChangeContext &&
        (role == AppRole.teacher ||
            (role == AppRole.guardian &&
                store.guardianPortalStudents.length > 1));

    final canShowSetup =
        showSchoolSetupProgress &&
        store.hasAdminPermissionForActiveSchool &&
        onOpenSchoolSetup != null;

    return PopupMenuButton<_SessionMenuAction>(
      tooltip: 'Цэс',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (context) => [
        if (canChangeContext)
          const PopupMenuItem(
            value: _SessionMenuAction.changeContext,
            child: Text('Сонголт солих'),
          ),
        if (canSwitchSchool)
          const PopupMenuItem(
            value: _SessionMenuAction.switchSchool,
            child: Text('Сургууль солих'),
          ),
        if (canShowSetup)
          const PopupMenuItem(
            value: _SessionMenuAction.schoolSetup,
            child: Text('Бэлтгэлийн явц'),
          ),
        const PopupMenuItem(
          value: _SessionMenuAction.logout,
          child: Text('Гарах'),
        ),
      ],
    );
  }
}
