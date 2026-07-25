import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../models/school.dart';
import '../models/user_account.dart';
import '../screens/admin/admin_school_home_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/guardian/guardian_child_selection_screen.dart';
import '../screens/guardian/guardian_home_screen.dart';
import '../screens/no_school_membership_screen.dart';
import '../screens/onboarding/school_setup_screen.dart';
import '../screens/school/school_selection_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/teacher_workspace_screen.dart';
import '../state/app_store.dart';

/// Routes a signed-in user through school context → role home.
abstract final class AppNavigation {
  static Future<void> enterAfterAccountSelected(
    BuildContext context,
    AppStore store,
    UserAccount user, {
    bool preferLastSchool = false,
    bool? rememberMe,
  }) async {
    await store.selectDevelopmentUser(user, rememberMe: rememberMe);
    if (!context.mounted) return;
    await continueFromSchoolResolution(
      context,
      store,
      preferLastSchool: preferLastSchool,
    );
  }

  static Future<void> continueFromSchoolResolution(
    BuildContext context,
    AppStore store, {
    bool preferLastSchool = true,
  }) async {
    final result = await store.resolveSchoolEntry(
      preferLastSchool: preferLastSchool,
    );
    if (!context.mounted) return;

    switch (result.kind) {
      case SchoolResolveKind.none:
        _replace(context, NoSchoolMembershipScreen(store: store));
      case SchoolResolveKind.single:
        await store.selectSchoolMembership(result.membership!);
        if (!context.mounted) return;
        await _enterRoleHome(context, store);
      case SchoolResolveKind.multiple:
        _replace(context, SchoolSelectionScreen(store: store));
    }
  }

  static Future<void> afterSchoolSelected(
    BuildContext context,
    AppStore store,
    UserSchoolMembership membership,
  ) async {
    await store.selectSchoolMembership(membership);
    if (!context.mounted) return;
    await _enterRoleHome(context, store);
  }

  static Future<void> switchSchoolAndReroute(
    BuildContext context,
    AppStore store,
    String schoolId,
  ) async {
    await store.switchSchool(schoolId);
    if (!context.mounted) return;
    await _enterRoleHome(context, store);
  }

  static Future<void> openGuardianDashboard(
    BuildContext context,
    AppStore store,
  ) async {
    _replace(context, GuardianHomeScreen(store: store));
  }

  static void openTeacherWorkspace(BuildContext context, AppStore store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeacherWorkspaceScreen(store: store),
      ),
    );
  }

  static Future<void> logoutToLogin(
    BuildContext context,
    AppStore store,
  ) async {
    await store.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen(store: store)),
      (route) => false,
    );
  }

  static Future<void> _enterRoleHome(
    BuildContext context,
    AppStore store,
  ) async {
    final role = store.activeContext.role ?? store.selectedDevelopmentRole;
    if (role == null) {
      _replace(context, NoSchoolMembershipScreen(store: store));
      return;
    }

    final Widget next;
    switch (role) {
      case AppRole.admin:
        next = store.isSchoolSetupIncomplete
            ? SchoolSetupScreen(store: store)
            : AdminSchoolHomeScreen(store: store);
      case AppRole.teacher:
        next = TeacherWorkspaceScreen(store: store);
      case AppRole.guardian:
        next = await resolveGuardianEntry(store);
      case AppRole.student:
        next = StudentHomeScreen(store: store);
    }
    if (!context.mounted) return;
    _replace(context, next);
  }

  /// Resolves guardian home vs child selection for the active school.
  static Future<Widget> resolveGuardianEntry(AppStore store) async {
    final children = store.guardianPortalStudents;
    if (children.isEmpty) {
      return GuardianHomeScreen(store: store);
    }
    if (children.length == 1) {
      await store.setGuardianStudentId(children.first.id);
      return GuardianHomeScreen(store: store);
    }

    final selectedId = store.guardianStudentId;
    final hasValidSelection =
        selectedId != null && children.any((c) => c.id == selectedId);
    if (hasValidSelection) {
      return GuardianHomeScreen(store: store);
    }
    return GuardianChildSelectionScreen(store: store);
  }

  static void _replace(BuildContext context, Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }
}
