import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../models/user_account.dart';
import '../navigation/app_navigation.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/edubridge_logo.dart';

/// Hidden development account switcher — not used on normal app startup.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  AppRole? _pickingRole;

  Future<void> _enterWithUser(UserAccount user) async {
    await AppNavigation.enterAfterAccountSelected(
      context,
      widget.store,
      user,
      preferLastSchool: false,
      rememberMe: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final picking = _pickingRole;
        final accounts = picking == null
            ? const <UserAccount>[]
            : widget.store.activeUsersForRole(picking);

        return Scaffold(
          appBar: AppBar(title: const Text('Туршилтын хэрэглэгч солих')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.gap),
                  const EduBridgeLogo(size: 56),
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    'Зөвхөн хөгжүүлэлт',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.itemSm),
                  Text(
                    picking == null
                        ? 'Үүргээ сонгоод туршилтын бүртгэлээ сонгоно уу'
                        : '${picking.label} бүртгэл сонгох',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionSm),
                  if (picking == null) ...[
                    _RoleCard(
                      title: AppRole.admin.label,
                      subtitle: 'admin1',
                      icon: Icons.admin_panel_settings_outlined,
                      selected:
                          widget.store.selectedDevelopmentRole == AppRole.admin,
                      onTap: () => setState(() => _pickingRole = AppRole.admin),
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    _RoleCard(
                      title: AppRole.teacher.label,
                      subtitle: 'teacher1',
                      icon: Icons.school_outlined,
                      selected:
                          widget.store.selectedDevelopmentRole ==
                          AppRole.teacher,
                      onTap: () =>
                          setState(() => _pickingRole = AppRole.teacher),
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    _RoleCard(
                      title: AppRole.guardian.label,
                      subtitle: 'guardian1',
                      icon: Icons.family_restroom_outlined,
                      selected:
                          widget.store.selectedDevelopmentRole ==
                          AppRole.guardian,
                      onTap: () =>
                          setState(() => _pickingRole = AppRole.guardian),
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    _RoleCard(
                      title: AppRole.student.label,
                      subtitle: 'student1',
                      icon: Icons.person_outline,
                      selected:
                          widget.store.selectedDevelopmentRole ==
                          AppRole.student,
                      onTap: () =>
                          setState(() => _pickingRole = AppRole.student),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _pickingRole = null),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Буцах'),
                      ),
                    ),
                    if (accounts.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Идэвхтэй бүртгэл байхгүй.\n'
                            'Тохиргоо → Хэрэглэгчийн эрх эсвэл тест өгөгдөл үүсгэнэ үү.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: accounts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.item),
                          itemBuilder: (context, index) {
                            final user = accounts[index];
                            final subtitle = _linkLabel(user);
                            return Card(
                              child: ListTile(
                                title: Text(user.username),
                                subtitle: Text(subtitle),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _enterWithUser(user),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _linkLabel(UserAccount user) {
    switch (user.role) {
      case AppRole.admin:
        return widget.store.teacherById(user.teacherId)?.fullName ?? 'Админ';
      case AppRole.teacher:
        return widget.store.teacherById(user.teacherId)?.fullName ??
            'Багш холбоогүй';
      case AppRole.guardian:
        return widget.store.guardianById(user.guardianId)?.fullName ??
            'Асран хамгаалагч холбоогүй';
      case AppRole.student:
        final s = user.studentId == null
            ? null
            : widget.store.studentById(user.studentId!);
        return s == null
            ? 'Сурагч холбоогүй'
            : '${s.fullName} (${s.className})';
    }
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card + 4),
          child: Row(
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary)
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
