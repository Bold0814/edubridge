import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'admin/admin_school_home_screen.dart';

/// Signed-in teacher account summary (internal screen — Back returns to workspace).
class TeacherAccountScreen extends StatelessWidget {
  const TeacherAccountScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.authenticatedUser;
    final teacherId = user?.teacherId ?? store.activeContext.teacherId;
    final teacher = teacherId == null ? null : store.teacherById(teacherId);
    final schoolName = store.activeSchool?.name ?? 'Сургууль';

    return Scaffold(
      appBar: AppBar(title: const Text('Бүртгэл'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Сургууль'),
            subtitle: Text(schoolName),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Нэр'),
            subtitle: Text(teacher?.fullName ?? user?.username ?? '—'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Нэвтрэх нэр'),
            subtitle: Text(user?.username ?? '—'),
          ),
          if (store.hasAdminPermissionForActiveSchool) ...[
            const SizedBox(height: AppSpacing.sectionSm),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => AdminSchoolHomeScreen(store: store),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Админ нүүр рүү'),
            ),
          ],
        ],
      ),
    );
  }
}
