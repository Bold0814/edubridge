import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../models/user_account.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'user_account_form_screen.dart';

/// Local user account management (prototype).
class UserAccountManagementScreen extends StatelessWidget {
  const UserAccountManagementScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {UserAccount? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserAccountFormScreen(store: store, existing: existing),
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context, UserAccount user) async {
    final plain = await store.resetUserPassword(user.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Түр нууц үг'),
        content: Text('Шинэ түр нууц үг (зөвхөн одоо харагдана):\n\n$plain'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ойлголоо'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, UserAccount user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Идэвхгүй болгох'),
        content: Text('"${user.username}" бүртгэлийг идэвхгүй болгох уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Идэвхгүй болгох'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await store.deactivateUserAccount(user.id);
  }

  String _linkLabel(UserAccount user) {
    switch (user.role) {
      case AppRole.admin:
        return store.teacherById(user.teacherId)?.fullName ?? 'Админ';
      case AppRole.teacher:
        return store.teacherById(user.teacherId)?.fullName ?? '—';
      case AppRole.guardian:
        return store.guardianById(user.guardianId)?.fullName ?? '—';
      case AppRole.student:
        final s = user.studentId == null
            ? null
            : store.studentById(user.studentId!);
        return s?.fullName ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Хэрэглэгчийн эрх')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Бүртгэл нэмэх',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final users = store.userAccounts;
          if (users.isEmpty) {
            return const Center(child: Text('Бүртгэл байхгүй'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.page,
              AppSpacing.page,
              88,
            ),
            itemCount: users.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.item),
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                child: ListTile(
                  title: Text(user.username),
                  subtitle: Text(
                    '${user.role.label} · ${_linkLabel(user)}'
                    '${user.isActive ? '' : ' · Идэвхгүй'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openForm(context, existing: user);
                        case 'reset':
                          _resetPassword(context, user);
                        case 'deactivate':
                          _deactivate(context, user);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Засах')),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Text('Нууц үг шинэчлэх'),
                      ),
                      if (user.isActive)
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Идэвхгүй болгох'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
