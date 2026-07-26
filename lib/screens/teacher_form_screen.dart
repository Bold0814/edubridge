import 'package:flutter/material.dart';

import '../models/teacher.dart';
import '../models/user_account.dart';
import '../services/password_rules.dart';
import '../services/phone_normalizer.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/admin_permission_gate.dart';

/// Багш нэмэх / засах (+ нэвтрэх эрх удирдлага).
class TeacherFormScreen extends StatefulWidget {
  const TeacherFormScreen({super.key, required this.store, this.existing});

  final AppStore store;
  final Teacher? existing;

  bool get isEditing => existing != null;

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;

  bool _createLogin = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _nameController = TextEditingController(text: t?.fullName ?? '');
    _phoneController = TextEditingController(text: t?.phone ?? '');
    _emailController = TextEditingController(text: t?.email ?? '');
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
    _createLogin = !widget.isEditing;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Teacher? get _teacher {
    final id = widget.existing?.id;
    if (id == null) return null;
    return widget.store.teacherById(id) ?? widget.existing;
  }

  UserAccount? get _linkedAccount {
    final id = _teacher?.id;
    if (id == null) return null;
    return widget.store.loginAccountForTeacher(id);
  }

  String _mapError(Object e) {
    if (e is PermissionDeniedException) {
      return e.message;
    }
    if (e is! ArgumentError) return 'Хадгалах үед алдаа гарлаа.';
    return switch (e.message) {
      'EMPTY' => 'Овог нэр хоосон байж болохгүй.',
      'EMPTY_PHONE' => 'Нэвтрэх эрх үүсгэхийн тулд утасны дугаар оруулна уу.',
      'EMPTY_USERNAME' => 'Нэвтрэх утас хоосон байж болохгүй.',
      'DUPLICATE_USERNAME' => 'Энэ утасны дугаар бүртгэлтэй байна.',
      'DUPLICATE_PHONE' => 'Энэ утасны дугаар өөр бүртгэлд ашиглагдаж байна.',
      'PASSWORD_MISMATCH' => PasswordRules.mismatchMessage,
      'INVALID_PASSWORD' =>
        PasswordRules.validateNewPassword(
              _passwordController.text,
              _confirmController.text,
            ) ??
            'Нууц үг шаардлага хангахгүй байна.',
      'TEACHER_ACCOUNT_EXISTS' => 'Энэ багшид нэвтрэх эрх аль хэдийн байна.',
      'UNSAFE_ACCOUNT_LINK' =>
        'Нэвтрэх эрх буруу холбогдсон байна. Тусдаа багшийн эрх үүсгэнэ үү.',
      'NOT_FOUND' => 'Бүртгэл олдсонгүй.',
      _ => 'Хадгалах үед алдаа гарлаа.',
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) throw ArgumentError('EMPTY');

      final duplicate = widget.store.teachers.any(
        (t) => t.fullName.trim() == name && t.id != widget.existing?.id,
      );
      if (duplicate) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ижил нэртэй багш'),
            content: const Text(
              'Ийм нэртэй багш аль хэдийн байна. Үргэлжлүүлэх үү?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Болих'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Үргэлжлүүлэх'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
        if (!mounted) return;
      }

      if (widget.isEditing) {
        final current = _teacher!;
        final phone = PhoneNormalizer.normalize(_phoneController.text);
        await widget.store.updateTeacher(
          current.copyWith(
            fullName: name,
            phone: phone,
            email: _emailController.text.trim(),
          ),
          allowDuplicate: true,
        );
        if (!mounted) return;
        final refreshed = widget.store.teacherById(current.id);
        if (refreshed != null) {
          _phoneController.text = refreshed.phone;
          _nameController.text = refreshed.fullName;
          _emailController.text = refreshed.email;
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Багшийн мэдээлэл амжилттай шинэчлэгдлээ.'),
          ),
        );
        return;
      }

      final createdLogin = await widget.store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: widget.store.nextTeacherId(),
          schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
          fullName: name,
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
        ),
        allowDuplicateName: true,
        createLogin: _createLogin,
        password: _passwordController.text,
        passwordConfirm: _confirmController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            createdLogin
                ? 'Багшийн мэдээлэл болон нэвтрэх эрх амжилттай үүслээ.'
                : 'Багшийн мэдээлэл амжилттай хадгалагдлаа.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createLoginForExisting() async {
    final teacher = _teacher;
    if (teacher == null) return;

    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Нэвтрэх эрх үүсгэх'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Нэвтрэх утас: ${PhoneNormalizer.normalize(teacher.phone).isEmpty ? '—' : PhoneNormalizer.normalize(teacher.phone)}',
                ),
                const SizedBox(height: AppSpacing.itemSm),
                const Text('Багш анх нэвтрээд нууц үгээ солино.'),
                const SizedBox(height: AppSpacing.gap),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Түр нууц үг',
                    helperText: PasswordRules.helperText,
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Нууц үг давтах',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Үүсгэх'),
            ),
          ],
        );
      },
    );

    final password = passwordCtrl.text;
    final confirm = confirmCtrl.text;
    passwordCtrl.dispose();
    confirmCtrl.dispose();

    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.store.createLoginForExistingTeacher(
        teacherId: teacher.id,
        password: password,
        passwordConfirm: confirm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Багшийн мэдээлэл болон нэвтрэх эрх амжилттай үүслээ.'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetPassword() async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Түр нууц үг шинэчлэх'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Багш анх нэвтрээд нууц үгээ солино.'),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Түр нууц үг',
                helperText: PasswordRules.helperText,
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Нууц үг давтах'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Шинэчлэх'),
          ),
        ],
      ),
    );
    final password = passwordCtrl.text;
    final confirm = confirmCtrl.text;
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    if (ok != true || !mounted) return;

    try {
      await widget.store.resetTeacherLoginPassword(
        teacherId: widget.existing!.id,
        password: password,
        passwordConfirm: confirm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Түр нууц үг шинэчлэгдлээ.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(e))));
    }
  }

  Future<void> _toggleActive(bool activate) async {
    try {
      await widget.store.setTeacherLoginActive(
        teacherId: widget.existing!.id,
        isActive: activate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activate
                ? 'Нэвтрэх эрх идэвхжлээ.'
                : 'Нэвтрэх эрх идэвхгүй боллоо.',
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapError(e))));
    }
  }

  Widget _buildLoginSection(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Нэвтрэх эрх', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Нэвтрэх эрх үүсгэх'),
            value: _createLogin,
            onChanged: _saving
                ? null
                : (value) => setState(() => _createLogin = value),
          ),
          if (_createLogin) ...[
            Text(
              'Багш анх нэвтрээд нууц үгээ солино.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Түр нууц үг',
                helperText: PasswordRules.helperText,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Нууц үг давтах'),
              textInputAction: TextInputAction.done,
            ),
          ],
        ],
      );
    }

    final teacher = _teacher!;
    final status = widget.store.teacherLoginStatusLabel(teacher.id);
    final account = _linkedAccount;
    final adminLinked = widget.store.adminAccountForTeacher(teacher.id);
    final loginPhone = account != null
        ? PhoneNormalizer.normalize(account.username)
        : PhoneNormalizer.normalize(teacher.phone);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Нэвтрэх эрх', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.itemSm),
            Text('Төлөв: $status'),
            if (account != null) ...[
              const SizedBox(height: 4),
              Text(
                'Нэвтрэх утас: ${loginPhone.isEmpty ? account.username : loginPhone}',
              ),
            ] else if (adminLinked != null) ...[
              const SizedBox(height: 4),
              Text(
                'Админ нэвтрэх нэр: ${adminLinked.username}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Админ нууц үгийг эндээс солихгүй. Багшийн утсаар тусдаа нэвтрэх эрх үүсгэж болно.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.gap),
            if (account == null)
              FilledButton(
                onPressed: _saving ? null : _createLoginForExisting,
                child: const Text('Нэвтрэх эрх үүсгэх'),
              )
            else ...[
              OutlinedButton(
                onPressed: _saving ? null : _resetPassword,
                child: const Text('Түр нууц үг шинэчлэх'),
              ),
              const SizedBox(height: AppSpacing.itemSm),
              if (account.isActive)
                OutlinedButton(
                  onPressed: _saving ? null : () => _toggleActive(false),
                  child: const Text('Идэвхгүй болгох'),
                )
              else
                OutlinedButton(
                  onPressed: _saving ? null : () => _toggleActive(true),
                  child: const Text('Идэвхжүүлэх'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPermissionGate(
      store: widget.store,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Багш засах' : 'Багш нэмэх'),
        ),
        body: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Овог нэр'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.gap),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Утас'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.gap),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'И-мэйл'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.section),
                _buildLoginSection(context),
                const SizedBox(height: AppSpacing.section),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Хадгалж байна…' : 'Хадгалах'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
