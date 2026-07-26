import 'package:flutter/material.dart';

import '../models/homework.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
import 'homework_create_screen.dart';
import 'homework_status_screen.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({
    super.key,
    required this.selectedClass,
    required this.store,
    this.subjectId,
  });

  final String selectedClass;
  final AppStore store;

  /// Explicit teaching subject; falls back to [AppStore.activeContext.subjectId].
  final int? subjectId;

  int? get _effectiveSubjectId => subjectId ?? store.activeContext.subjectId;

  String? get _effectiveSubjectName {
    final id = _effectiveSubjectId;
    if (id == null) return null;
    return store.subjectById(id)?.name;
  }

  Future<void> _openCreateScreen(
    BuildContext context, {
    Homework? existing,
  }) async {
    final activeSubjectName = _effectiveSubjectName;
    final initialSubject =
        existing?.subject ??
        activeSubjectName ??
        store.journalSubjectFor(selectedClass);
    final lockSubject =
        _effectiveSubjectId != null &&
        existing == null &&
        activeSubjectName != null;

    await Navigator.push<Homework>(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkCreateScreen(
          className: selectedClass,
          store: store,
          existing: existing,
          initialSubject: initialSubject,
          lockSubject: lockSubject,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openStatus(BuildContext context, Homework item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomeworkStatusScreen(store: store, homework: item),
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    Homework item,
    String action,
  ) async {
    if (action == 'status') {
      await _openStatus(context, item);
      return;
    }
    if (action == 'edit' || action == 'delete') {
      if (!store.teacherCanEditSubjectNamed(
        classId: selectedClass,
        subjectName: item.subject,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStore.subjectEditDeniedMessage)),
        );
        return;
      }
    }
    if (action == 'edit') {
      await _openCreateScreen(context, existing: item);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDelete(context);
      if (!ok) return;
      try {
        await store.deleteHomework(item.id);
      } on PermissionDeniedException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      if (!context.mounted) return;
      showDeletedSnackBar(context);
    }
  }

  Future<void> _onLongPress(BuildContext context, Homework item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Гүйцэтгэл'),
                onTap: () => Navigator.pop(sheetContext, 'status'),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Засах'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Устгах'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    await _onMenuSelected(context, item, action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final effectiveSubjectId = _effectiveSubjectId;
        final subjectName = _effectiveSubjectName;
        final homeworkList = store.homeworkFor(
          selectedClass,
          subjectId: effectiveSubjectId,
        );
        final isEmpty = homeworkList.isEmpty;
        final title = subjectName != null
            ? '$selectedClass · $subjectName · Даалгавар'
            : '$selectedClass · Даалгавар';

        return Scaffold(
          appBar: AppBar(title: Text(title), centerTitle: true),
          floatingActionButton:
              store.teacherCanEditActiveSubjectInClass(selectedClass)
              ? FloatingActionButton(
                  onPressed: () => _openCreateScreen(context),
                  tooltip: 'Шинэ даалгавар',
                  child: const Icon(Icons.add),
                )
              : null,
          body: isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Text(
                      'Даалгавар байхгүй байна',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    88,
                  ),
                  children: [
                    ...homeworkList.map((item) {
                      final isDone = item.status == HomeworkStatus.done;
                      final statusColor = isDone
                          ? AppColors.success
                          : AppColors.homework;
                      final showSubjectOnCard = effectiveSubjectId == null;

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radius,
                          ),
                          onTap: () => _openStatus(context, item),
                          onLongPress: () => _onLongPress(context, item),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.card),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isDone
                                      ? Icons.assignment_turned_in
                                      : Icons.assignment,
                                  color: statusColor,
                                ),
                                const SizedBox(width: AppSpacing.gap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (showSubjectOnCard) ...[
                                        Text(
                                          item.subject,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.itemSm,
                                        ),
                                      ],
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.itemSm),
                                      Text(item.description),
                                      const SizedBox(height: AppSpacing.item),
                                      Text('Дуусгах хугацаа: ${item.dueDate}'),
                                      const SizedBox(height: AppSpacing.item),
                                      Text(
                                        item.status.label,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Цэс',
                                  onSelected: (value) =>
                                      _onMenuSelected(context, item, value),
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'status',
                                      child: Text('Гүйцэтгэл'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('✏️ Засах'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('🗑 Устгах'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
