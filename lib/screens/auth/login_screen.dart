import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import '../onboarding/create_school_screen.dart';
import 'first_time_access_screen.dart';

/// Local username/password sign-in (no cloud auth).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await widget.store.login(
      username: _usernameController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (result != LoginResult.success) {
      setState(() {
        _submitting = false;
        _error = result.message;
      });
      return;
    }

    await AppNavigation.continueFromSchoolResolution(
      context,
      widget.store,
      preferLastSchool: false,
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.gap),
                  const Center(child: EduBridgeLogo(size: 96)),
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    'EduBridge',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ХОЛБОО. ИТГЭЛ. ИРЭЭДҮЙ.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Нэвтрэх нэр, утас эсвэл сурагчийн код',
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'PIN эсвэл нууц үг',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Харуулах' : 'Нуух',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.itemSm),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _rememberMe,
                    onChanged: _submitting
                        ? null
                        : (value) {
                            setState(() => _rememberMe = value ?? false);
                          },
                    title: const Text('Намайг сана'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.itemSm),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sectionSm),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Нэвтрэх'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirstTimeAccessScreen(store: widget.store),
                              ),
                            );
                          },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Анх удаа нэвтрэх'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateSchoolScreen(store: widget.store),
                              ),
                            );
                          },
                    child: const Text('Шинэ сургууль үүсгэх'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
