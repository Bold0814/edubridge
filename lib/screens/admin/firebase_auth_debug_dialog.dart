import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/firebase_auth_service.dart';
import '../../theme/app_spacing.dart';

/// Debug-only Firebase Auth probe dialog (never used in release UI).
class FirebaseAuthDebugDialog extends StatefulWidget {
  const FirebaseAuthDebugDialog({super.key, this.authService});

  final FirebaseAuthService? authService;

  static const title = 'Firebase Auth шалгах';
  static const createButtonLabel = 'Туршилтын эрх үүсгэх';
  static const signInButtonLabel = 'Нэвтрэх';
  static const signOutButtonLabel = 'Гарах';
  static const deleteTestUserButtonLabel = 'Туршилтын хэрэглэгч устгах';
  static const invalidEmailMessage = 'Зөв имэйл хаяг оруулна уу.';

  @override
  State<FirebaseAuthDebugDialog> createState() =>
      _FirebaseAuthDebugDialogState();
}

class _FirebaseAuthDebugDialogState extends State<FirebaseAuthDebugDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FirebaseAuthService _auth;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _auth = widget.authService ?? FirebaseAuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!kDebugMode || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _snackFailure(FirebaseAuthServiceException e) {
    if (kDebugMode && e.code != null && e.code!.isNotEmpty) {
      _snack('${e.message}\nFirebase code: ${e.code}');
    } else {
      _snack(e.message);
    }
  }

  String? _validatedEmail() {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _snack(FirebaseAuthDebugDialog.invalidEmailMessage);
      return null;
    }
    return email;
  }

  Future<void> _create() async {
    await _run(() async {
      final email = _validatedEmail();
      if (email == null) return;
      try {
        await _auth.createAccount(
          internalEmail: email,
          password: _passwordController.text,
        );
        if (!mounted) return;
        _snack(FirebaseAuthService.createSuccessMessage);
      } on FirebaseAuthServiceException catch (e) {
        if (!mounted) return;
        _snackFailure(e);
      }
    });
  }

  Future<void> _signIn() async {
    await _run(() async {
      final email = _validatedEmail();
      if (email == null) return;
      try {
        await _auth.signIn(
          internalEmail: email,
          password: _passwordController.text,
        );
        if (!mounted) return;
        _snack(FirebaseAuthService.signInSuccessMessage);
      } on FirebaseAuthServiceException catch (e) {
        if (!mounted) return;
        _snackFailure(e);
      }
    });
  }

  Future<void> _signOut() async {
    await _run(() async {
      try {
        await _auth.signOut();
        if (!mounted) return;
        _snack(FirebaseAuthService.signOutSuccessMessage);
      } on FirebaseAuthServiceException catch (e) {
        if (!mounted) return;
        _snackFailure(e);
      }
    });
  }

  Future<void> _deleteTestUser() async {
    await _run(() async {
      try {
        await _auth.deleteDebugTestUser(password: _passwordController.text);
        if (!mounted) return;
        _snack(FirebaseAuthService.deleteDebugUserSuccessMessage);
      } on FirebaseAuthServiceException catch (e) {
        if (!mounted) return;
        _snackFailure(e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(FirebaseAuthDebugDialog.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Имэйл'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _passwordController,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Нууц үг'),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.gap),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _deleteTestUser,
                child: const Text(
                  FirebaseAuthDebugDialog.deleteTestUserButtonLabel,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Хаах'),
        ),
        TextButton(
          onPressed: _busy ? null : _signOut,
          child: const Text(FirebaseAuthDebugDialog.signOutButtonLabel),
        ),
        TextButton(
          onPressed: _busy ? null : _signIn,
          child: const Text(FirebaseAuthDebugDialog.signInButtonLabel),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: const Text(FirebaseAuthDebugDialog.createButtonLabel),
        ),
      ],
    );
  }
}
