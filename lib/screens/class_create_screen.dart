import 'package:flutter/material.dart';

import '../models/class_naming.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'teacher_form_screen.dart';

/// Dedicated form to create a school class (avoids dialog dispose crashes).
class ClassCreateScreen extends StatefulWidget {
  const ClassCreateScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ClassCreateScreen> createState() => _ClassCreateScreenState();
}

class _ClassCreateScreenState extends State<ClassCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sectionController = TextEditingController();
  int? _gradeLevel;
  String? _homeroomTeacherId;
  bool _saving = false;

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  String get _previewName {
    final grade = _gradeLevel;
    if (grade == null) return 'Ангийн нэр';
    final section = ClassNaming.normalizeSection(_sectionController.text);
    try {
      return ClassNaming.displayName(gradeLevel: grade, section: section);
    } catch (_) {
      return ClassNaming.gradeLevelLabel(grade);
    }
  }

  Future<void> _openAddTeacher() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeacherFormScreen(store: widget.store),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final grade = _gradeLevel;
    if (grade == null) return;

    setState(() => _saving = true);
    try {
      await widget.store.addSchoolClass(
        gradeLevel: grade,
        section: _sectionController.text,
        homeroomTeacherId: _homeroomTeacherId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'EMPTY_CLASS' => 'Ангийн түвшингээ сонгоно уу',
        'INVALID_GRADE_LEVEL' => 'Анги 1–12 байх ёстой',
        'INVALID_SECTION' => 'Ангийн бүлэг буруу байна',
        'DUPLICATE_CLASS' => 'Ийм анги аль хэдийн байна',
        _ => 'Анги нэмэхэд алдаа гарлаа',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on PermissionDeniedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ үйлдлийг хийх эрхгүй байна')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers = widget.store.activeTeachers;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Анги нэмэх'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _gradeLevel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ангийн түвшин',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Анги сонгох'),
              items: [
                for (final grade in ClassNaming.gradeLevels)
                  DropdownMenuItem<int>(
                    value: grade,
                    child: Text(ClassNaming.gradeLevelLabel(grade)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _gradeLevel = value);
                    },
              validator: (value) {
                if (value == null) return 'Ангийн түвшингээ сонгоно уу';
                if (!ClassNaming.isValidGradeLevel(value)) {
                  return 'Анги 1–12 байх ёстой';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextFormField(
              controller: _sectionController,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Бүлэг (заавал биш)',
                hintText: 'ж: а, б, в',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) => ClassNaming.validateSectionInput(value),
            ),
            const SizedBox(height: AppSpacing.item),
            Text(
              'Нэр: $_previewName',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            if (teachers.isEmpty) ...[
              const Text('Багш бүртгээгүй байна'),
              const SizedBox(height: AppSpacing.item),
              OutlinedButton(
                onPressed: _saving ? null : _openAddTeacher,
                child: const Text('Багш нэмэх'),
              ),
            ] else
              DropdownButtonFormField<String?>(
                initialValue: _homeroomTeacherId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Анги удирдсан багш',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Сонгохгүй'),
                  ),
                  for (final teacher in teachers)
                    DropdownMenuItem<String?>(
                      value: teacher.id,
                      child: Text(
                        teacher.fullName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _homeroomTeacherId = value);
                      },
              ),
            const SizedBox(height: AppSpacing.section),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Нэмэх'),
            ),
          ],
        ),
      ),
    );
  }
}
