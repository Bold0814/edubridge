import 'package:flutter/material.dart';

import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openForm(BuildContext context, {Student? student}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentFormScreen(
          classId: selectedClass,
          schoolId: store.activeSchoolId ?? AppStore.defaultSchoolId,
          store: store,
          student: student,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openDetail(BuildContext context, Student student) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          selectedClass: selectedClass,
          store: store,
          subjectId: store.activeContext.subjectId,
          selectedSubject: store.activeSubjectName,
          selectedTerm: store.journalTermFor(selectedClass),
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _confirmDelete(BuildContext context, Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Сурагч устгах'),
          content: Text('${student.fullName}-ийг устгах уу?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Устгах'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await store.deleteStudent(selectedClass, student.id);
    } on PermissionDeniedException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Сурагч устгагдлаа.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final students = store.studentsFor(selectedClass);
        final isEmpty = students.isEmpty;
        final canManage = store.canManageStudents;

        return Scaffold(
          appBar: AppBar(
            title: Text('$selectedClass · Сурагчид'),
            centerTitle: true,
          ),
          floatingActionButton: canManage
              ? FloatingActionButton(
                  onPressed: () => _openForm(context),
                  tooltip: 'Сурагч нэмэх',
                  child: const Icon(Icons.add),
                )
              : null,
          body: isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: const Text(
                      'Сурагч бүртгээгүй байна',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    canManage ? 88 : AppSpacing.page,
                  ),
                  itemCount: students.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                        child: Text(
                          'Нийт сурагч: ${students.length}',
                          style: theme.textTheme.titleMedium,
                        ),
                      );
                    }
                    final student = students[index - 1];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.item),
                      child: ListTile(
                        onTap: () => _openDetail(context, student),
                        leading: Icon(
                          student.gender == StudentGender.male
                              ? Icons.man
                              : Icons.woman,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(student.fullName),
                        subtitle: Text(
                          student.guardian?.isNotEmpty == true
                              ? 'Асран хамгаалагч: ${student.guardian}'
                              : 'Регистр: ${student.register ?? '—'}',
                        ),
                        trailing: canManage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Засах',
                                    onPressed: () =>
                                        _openForm(context, student: student),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Устгах',
                                    onPressed: () =>
                                        _confirmDelete(context, student),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
