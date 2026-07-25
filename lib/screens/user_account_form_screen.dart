import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../models/user_account.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

class UserAccountFormScreen extends StatefulWidget {
  const UserAccountFormScreen({super.key, required this.store, this.existing});

  final AppStore store;
  final UserAccount? existing;

  bool get isEditing => existing != null;

  @override
  State<UserAccountFormScreen> createState() => _UserAccountFormScreenState();
}

class _UserAccountFormScreenState extends State<UserAccountFormScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late AppRole _role;
  String? _teacherId;
  String? _guardianId;
  String? _studentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController();
    _role = e?.role ?? AppRole.teacher;
    _teacherId = e?.teacherId;
    _guardianId = e?.guardianId;
    _studentId = e?.studentId;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await widget.store.updateUserAccount(
          widget.existing!.copyWith(
            username: _usernameController.text.trim(),
            role: _role,
            teacherId: (_role == AppRole.teacher || _role == AppRole.admin)
                ? _teacherId
                : null,
            guardianId: _role == AppRole.guardian ? _guardianId : null,
            studentId: _role == AppRole.student ? _studentId : null,
            clearTeacherId: _role != AppRole.teacher && _role != AppRole.admin,
            clearGuardianId: _role != AppRole.guardian,
            clearStudentId: _role != AppRole.student,
          ),
        );
      } else {
        final password = _passwordController.text;
        if (password.isEmpty) {
          throw ArgumentError('EMPTY_PASSWORD');
        }
        await widget.store.addUserAccount(
          UserAccount(
            id: widget.store.nextUserId(),
            username: _usernameController.text.trim(),
            passwordHash: '',
            role: _role,
            teacherId: _teacherId,
            guardianId: _guardianId,
            studentId: _studentId,
            createdAt: DateTime.now(),
          ),
          plainPassword: password,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'EMPTY_USERNAME' => 'Хэрэглэгчийн нэр хоосон байж болохгүй.',
        'DUPLICATE_USERNAME' => 'Ийм нэртэй бүртгэл аль хэдийн байна.',
        'MISSING_LINK' => 'Холбох багш/асран хамгаалагч/сурагчийг сонгоно уу.',
        'INVALID_LINK' => 'Холбосон бүртгэл олдсонгүй.',
        'ROLE_LINK_MISMATCH' => 'Үүрэг болон холбоос таарахгүй байна.',
        'EMPTY_PASSWORD' => 'Нууц үг оруулна уу.',
        _ => 'Хадгалах үед алдаа гарлаа.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers = widget.store.activeTeachers;
    final guardians = widget.store.activeGuardians;
    final students = widget.store.allStudents;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Бүртгэл засах' : 'Бүртгэл нэмэх'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Хэрэглэгчийн нэр'),
          ),
          if (!widget.isEditing) ...[
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Нууц үг'),
            ),
          ],
          const SizedBox(height: AppSpacing.gap),
          DropdownButtonFormField<AppRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Үүрэг'),
            items: [
              for (final role in AppRole.values)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _role = value;
                _teacherId = null;
                _guardianId = null;
                _studentId = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.gap),
          if (_role == AppRole.teacher || _role == AppRole.admin)
            DropdownButtonFormField<String>(
              key: ValueKey('teacher-$_teacherId'),
              initialValue: _teacherId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _role == AppRole.admin
                    ? 'Ажилтан (заавал биш)'
                    : 'Багш',
              ),
              items: [
                for (final t in teachers)
                  DropdownMenuItem(value: t.id, child: Text(t.fullName)),
              ],
              onChanged: (value) => setState(() => _teacherId = value),
            ),
          if (_role == AppRole.guardian)
            DropdownButtonFormField<String>(
              key: ValueKey('guardian-$_guardianId'),
              initialValue: _guardianId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Асран хамгаалагч'),
              items: [
                for (final g in guardians)
                  DropdownMenuItem(value: g.id, child: Text(g.fullName)),
              ],
              onChanged: (value) => setState(() => _guardianId = value),
            ),
          if (_role == AppRole.student)
            DropdownButtonFormField<String>(
              key: ValueKey('student-$_studentId'),
              initialValue: _studentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Сурагч'),
              items: [
                for (final s in students)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.fullName} (${s.className})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _studentId = value),
            ),
          const SizedBox(height: AppSpacing.section),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Хадгалж байна…' : 'Хадгалах'),
          ),
        ],
      ),
    );
  }
}
