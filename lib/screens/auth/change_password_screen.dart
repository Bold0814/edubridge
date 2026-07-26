import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../services/password_rules.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';

/// Forced password change after temporary teacher password login.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final validation = PasswordRules.validateNewPassword(
      _passwordController.text,
      _confirmController.text,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.store.completeRequiredPasswordChange(
        newPassword: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      await AppNavigation.continueFromSchoolResolution(
        context,
        widget.store,
        preferLastSchool: false,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (e.message) {
          'PASSWORD_MISMATCH' => PasswordRules.mismatchMessage,
          'INVALID_PASSWORD' =>
            PasswordRules.validateNewPassword(
                  _passwordController.text,
                  _confirmController.text,
                ) ??
                PasswordRules.combinedRequirementsMessage,
          _ => 'Нууц үг солиход алдаа гарлаа.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Шинэ нууц үг үүсгэх')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Center(child: EduBridgeLogo(size: 72)),
            const SizedBox(height: AppSpacing.sectionSm),
            Text(
              'Шинэ нууц үг үүсгэх',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.itemSm),
            Text(
              'Түр нууц үгээ солино уу.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.section),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Шинэ нууц үг',
                helperText: PasswordRules.helperText,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Нууц үг давтах'),
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
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
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
