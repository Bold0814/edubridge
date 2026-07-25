import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import 'school_setup_screen.dart';

/// Creates the first school administrator account after school creation.
class CreateSchoolAdminScreen extends StatefulWidget {
  const CreateSchoolAdminScreen({
    super.key,
    required this.store,
    required this.schoolId,
    required this.schoolName,
  });

  final AppStore store;
  final String schoolId;
  final String schoolName;

  @override
  State<CreateSchoolAdminScreen> createState() =>
      _CreateSchoolAdminScreenState();
}

class _CreateSchoolAdminScreenState extends State<CreateSchoolAdminScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _created = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _created) return;
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      setState(() => _error = 'Овог нэрээ оруулна уу');
      return;
    }
    if (username.isEmpty) {
      setState(() => _error = 'Нэвтрэх нэрээ оруулна уу');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Нууц үгээ оруулна уу');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Нууц үг таарахгүй байна');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.store.createFirstSchoolAdmin(
        schoolId: widget.schoolId,
        fullName: name,
        phone: _phoneController.text,
        email: _emailController.text,
        username: username,
        password: password,
      );
      _created = true;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => SchoolSetupScreen(store: widget.store),
        ),
        (route) => false,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (e.message) {
          'DUPLICATE_USERNAME' => 'Энэ нэвтрэх нэр аль хэдийн бүртгэлтэй',
          'EMPTY_NAME' => 'Овог нэрээ оруулна уу',
          'EMPTY_USERNAME' => 'Нэвтрэх нэрээ оруулна уу',
          'EMPTY_PASSWORD' => 'Нууц үгээ оруулна уу',
          _ => 'Бүртгэл үүсгэхэд алдаа гарлаа',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Бүртгэл үүсгэхэд алдаа гарлаа';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Админ бүртгэл')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: EduBridgeLogo(size: 56)),
              const SizedBox(height: AppSpacing.gap),
              Text(
                widget.schoolName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Эхний админ бүртгэл',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Овог нэр'),
              ),
              const SizedBox(height: AppSpacing.gap),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Утас (заавал биш)',
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'И-мэйл (заавал биш)',
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: 'Нэвтрэх нэр'),
              ),
              const SizedBox(height: AppSpacing.gap),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Нууц үг',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              TextField(
                controller: _confirmController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Нууц үг давтах'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.gap),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              FilledButton(
                onPressed: (_submitting || _created) ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Админ үүсгэх'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
