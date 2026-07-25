import 'package:flutter/material.dart';

import '../models/guardian.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'guardian_form_screen.dart';
import 'guardian_student_link_screen.dart';

class GuardianListScreen extends StatelessWidget {
  const GuardianListScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {Guardian? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GuardianFormScreen(store: store, existing: existing),
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, Guardian guardian) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Идэвхгүй болгох'),
        content: Text('"${guardian.fullName}"-ийг идэвхгүй болгох уу?'),
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
    await store.deactivateGuardian(guardian.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Асран хамгаалагчид')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Нэмэх',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.guardians;
          if (items.isEmpty) {
            return const Center(child: Text('Асран хамгаалагч байхгүй'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.page,
              AppSpacing.page,
              88,
            ),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.item),
            itemBuilder: (context, index) {
              final guardian = items[index];
              final links = store.linksForGuardian(guardian.id);
              final children = links
                  .map((l) {
                    final s = store.studentById(l.studentId);
                    if (s == null) return null;
                    return '${s.fullName} — ${s.className} — ${l.relationship}';
                  })
                  .whereType<String>()
                  .join('\n');
              return Card(
                child: ListTile(
                  title: Text(guardian.fullName),
                  subtitle: Text(
                    [
                      if (guardian.phone.isNotEmpty) guardian.phone,
                      if (!guardian.isActive) 'Идэвхгүй',
                      if (children.isNotEmpty) 'Хүүхдүүд:\n$children',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openForm(context, existing: guardian);
                        case 'links':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuardianStudentLinkScreen(
                                store: store,
                                guardian: guardian,
                              ),
                            ),
                          );
                        case 'deactivate':
                          _deactivate(context, guardian);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Засах')),
                      const PopupMenuItem(
                        value: 'links',
                        child: Text('Хүүхэд холбох'),
                      ),
                      if (guardian.isActive)
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
