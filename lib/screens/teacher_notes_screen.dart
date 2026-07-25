import 'package:flutter/material.dart';

import '../models/student.dart';
import '../models/teacher_note.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/learner_access_gate.dart';
import 'teacher_note_form_screen.dart';

/// Teacher list of notes for students in [selectedClass]. Create / edit / delete.
class TeacherNotesScreen extends StatelessWidget {
  const TeacherNotesScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openForm(BuildContext context, {TeacherNote? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherNoteFormScreen(
          className: selectedClass,
          store: store,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    TeacherNote item,
    String action,
  ) async {
    if (action == 'edit') {
      await _openForm(context, existing: item);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDelete(context);
      if (!ok) return;
      await store.deleteTeacherNote(item.id);
      if (!context.mounted) return;
      showDeletedSnackBar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Зөвлөгөө'), centerTitle: true),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final notes = store.teacherNotesForClass(selectedClass);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                '$selectedClass анги',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Шинэ зөвлөгөө'),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              if (notes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Зөвлөгөө байхгүй')),
                )
              else
                ...notes.map((item) {
                  final student = store.studentById(item.studentId);
                  final teacher = store.teacherById(item.teacherId);
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                      onLongPress: () async {
                        final action = await showEditDeleteMenu(context);
                        if (action == null || !context.mounted) return;
                        await _onMenuSelected(context, item, action);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.card),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.gap),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.itemSm),
                                  Text(
                                    [
                                      student?.fullName ?? item.studentId,
                                      item.priority.label,
                                      if (teacher != null) teacher.fullName,
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: AppSpacing.itemSm),
                                  Text(
                                    item.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
          );
        },
      ),
    );
  }
}

/// Read-only notes list for Student / Guardian (newest first).
class LearnerNotesScreen extends StatelessWidget {
  const LearnerNotesScreen({
    super.key,
    required this.store,
    required this.student,
    required this.forGuardian,
  });

  final AppStore store;
  final Student student;
  final bool forGuardian;

  @override
  Widget build(BuildContext context) {
    return LearnerAccessGate(
      store: store,
      student: student,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = forGuardian
              ? store.notesVisibleToGuardian(student)
              : store.notesVisibleToStudent(student);

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Зөвлөгөө')),
            body: items.isEmpty
                ? const Center(child: Text('Зөвлөгөө байхгүй'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.item),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final teacher = store.teacherById(item.teacherId);
                      String? subjectName;
                      if (item.subjectId != null) {
                        for (final subject in store.activeSubjects) {
                          if (subject.id == item.subjectId) {
                            subjectName = subject.name;
                            break;
                          }
                        }
                      }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.card),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    item.priority.label,
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  ?teacher?.fullName,
                                  ?subjectName,
                                  _formatCreatedAt(item),
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.item),
                              Text(item.message),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  String _formatCreatedAt(TeacherNote note) {
    final date = note.createdAtDate;
    if (date == null) return note.createdAt;
    return '${date.year} оны ${date.month} сарын ${date.day}';
  }
}
