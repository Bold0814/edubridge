import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/pin_rules.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import 'login_screen.dart';

/// Self-service PIN creation after successful first-time identity checks.
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key, required this.store, required this.userId});

  final AppStore store;
  final String userId;

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final error = PinRules.validateNewPin(
      _pinController.text,
      _confirmController.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.store.activateAccountWithPin(
        userId: widget.userId,
        pin: _pinController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нэвтрэх эрх амжилттай идэвхжлээ.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(store: widget.store),
        ),
        (route) => false,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message == 'ALREADY_ACTIVE'
            ? 'Энэ бүртгэл идэвхжсэн байна. Нэвтрэх хэсгээр орно уу.'
            : 'Мэдээлэл тохирохгүй байна.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PIN үүсгэх')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Center(child: EduBridgeLogo(size: 72)),
            const SizedBox(height: AppSpacing.sectionSm),
            Text(
              'Шинэ PIN тохируулах',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Шинэ PIN'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'PIN давтах'),
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
                  : const Text('Идэвхжүүлэх'),
            ),
          ],
        ),
      ),
    );
  }
}
