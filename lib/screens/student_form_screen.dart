import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/admin_permission_gate.dart';

const _guardianRelationships = [
  'Ээж',
  'Аав',
  'Асран хамгаалагч',
  'Эмээ',
  'Өвөө',
  'Ах',
  'Эгч',
  'Бусад',
];

/// Create/edit a student for a fixed class (no class dropdown).
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({
    super.key,
    required this.classId,
    required this.schoolId,
    required this.store,
    this.student,
  });

  /// Class id (equals class name in current schema).
  final String classId;
  final String schoolId;
  final AppStore store;
  final Student? student;

  bool get isEditing => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lastNameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _registerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _guardianNameController;
  late final TextEditingController _guardianPhoneController;
  late final TextEditingController _guardianEmailController;

  StudentGender? _gender;
  String? _relationship;
  bool _saving = false;

  String get _classLabel {
    final schoolClass = widget.store.schoolClassById(widget.classId);
    return schoolClass?.name ?? widget.classId;
  }

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _lastNameController = TextEditingController(text: student?.lastName ?? '');
    _firstNameController = TextEditingController(
      text: student?.firstName ?? '',
    );
    _registerController = TextEditingController(text: student?.register ?? '');
    _phoneController = TextEditingController(text: student?.phone ?? '');
    _guardianNameController = TextEditingController(
      text: student?.guardian ?? '',
    );
    _guardianPhoneController = TextEditingController();
    _guardianEmailController = TextEditingController();
    _gender = student?.gender;

    if (student != null) {
      final links = widget.store.guardianStudentLinks
          .where((l) => l.studentId == student.id)
          .toList();
      if (links.isNotEmpty) {
        final link = links.first;
        _relationship = link.relationship;
        final guardian = widget.store.guardianById(link.guardianId);
        if (guardian != null) {
          _guardianNameController.text = guardian.fullName;
          _guardianPhoneController.text = guardian.phone;
          _guardianEmailController.text = guardian.email;
        }
      }
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _registerController.dispose();
    _phoneController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    super.dispose();
  }

  Future<void> _showGeneratedCode(String code) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Сурагч нэмэгдлээ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText('Сурагчийн код: $code'),
              const SizedBox(height: AppSpacing.gap),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Код хууллаа.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Хуулах'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Хаах'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    if (_gender == null || !valid) {
      if (_gender == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Хүйсээ сонгоно уу')));
      }
      return;
    }
    if (_relationship == null || _relationship!.trim().isEmpty) return;

    setState(() => _saving = true);

    final register = _registerController.text.trim();
    final phone = _phoneController.text.trim();
    final guardianName = _guardianNameController.text.trim();
    final guardianPhone = _guardianPhoneController.text.trim();
    final guardianEmail = _guardianEmailController.text.trim();

    try {
      if (widget.isEditing) {
        final updated = widget.student!.copyWith(
          lastName: _lastNameController.text.trim(),
          firstName: _firstNameController.text.trim(),
          gender: _gender,
          register: register.isEmpty ? null : register,
          phone: phone.isEmpty ? null : phone,
          guardian: guardianName,
          clearRegister: register.isEmpty,
          clearPhone: phone.isEmpty,
        );
        await widget.store.updateStudent(updated);
        await widget.store.linkRequiredGuardianToStudent(
          studentId: updated.id,
          guardianFullName: guardianName,
          guardianPhone: guardianPhone,
          guardianEmail: guardianEmail.isEmpty ? null : guardianEmail,
          relationship: _relationship!,
          schoolId: widget.schoolId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сурагчийн мэдээлэл шинэчлэгдлээ.')),
        );
        Navigator.pop(context, true);
      } else {
        final student = Student(
          id: widget.store.nextStudentId(widget.classId),
          className: widget.classId,
          lastName: _lastNameController.text.trim(),
          firstName: _firstNameController.text.trim(),
          gender: _gender!,
          register: register.isEmpty ? null : register,
          phone: phone.isEmpty ? null : phone,
          guardian: guardianName,
        );
        final saved = await widget.store.addStudentWithRequiredGuardian(
          student: student,
          guardianFullName: guardianName,
          guardianPhone: guardianPhone,
          guardianEmail: guardianEmail.isEmpty ? null : guardianEmail,
          relationship: _relationship!,
          schoolId: widget.schoolId,
        );
        if (!mounted) return;
        final code = saved.studentCode ?? '';
        if (code.isNotEmpty) {
          await _showGeneratedCode(code);
        }
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } on ArgumentError catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Хадгалах үед алдаа гарлаа. Мэдээлэл хадгалагдаагүй.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminPermissionGate(
      store: widget.store,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Сурагч засах' : 'Сурагч нэмэх'),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text('Сурагчийн мэдээлэл', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Овог'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Овгоо оруулна уу';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Нэр'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Нэрээ оруулна уу';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.gap),
              Text(
                'Анги: $_classLabel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              DropdownButtonFormField<StudentGender>(
                initialValue: _gender,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Хүйс'),
                hint: const Text('Хүйс сонгох'),
                items: [
                  for (final gender in StudentGender.values)
                    DropdownMenuItem(value: gender, child: Text(gender.label)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _gender = value),
                validator: (value) {
                  if (value == null) return 'Хүйсээ сонгоно уу';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _registerController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Регистр (заавал биш)',
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Утас (заавал биш)',
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Text('Асран хамгаалагч', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _guardianNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Овог нэр'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Асран хамгаалагчийн нэрийг оруулна уу';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _guardianPhoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Утас'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Асран хамгаалагчийн утсыг оруулна уу';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.gap),
              TextFormField(
                controller: _guardianEmailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'И-мэйл (заавал биш)',
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Хүүхэдтэй ямар холбоотой',
                ),
                hint: const Text('Сонгох'),
                items: [
                  for (final item in _guardianRelationships)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _relationship = value),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Хүүхэдтэй ямар холбоотойг сонгоно уу';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              8,
              AppSpacing.page,
              AppSpacing.page,
            ),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Хадгалах' : 'Сурагч нэмэх'),
            ),
          ),
        ),
      ),
    );
  }
}
