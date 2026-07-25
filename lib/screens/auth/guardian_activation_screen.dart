import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import 'create_pin_screen.dart';

/// First-time guardian identity check (phone + linked child student code).
class GuardianActivationScreen extends StatefulWidget {
  const GuardianActivationScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<GuardianActivationScreen> createState() =>
      _GuardianActivationScreenState();
}

class _GuardianActivationScreenState extends State<GuardianActivationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final lookup = widget.store.lookupGuardianActivation(
      phone: _phoneController.text,
      studentCode: _codeController.text,
    );
    switch (lookup.result) {
      case ActivationLookupResult.ok:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CreatePinScreen(
              store: widget.store,
              userId: lookup.account!.id,
            ),
          ),
        );
      case ActivationLookupResult.alreadyActive:
        setState(
          () =>
              _error = 'Энэ бүртгэл идэвхжсэн байна. Нэвтрэх хэсгээр орно уу.',
        );
      case ActivationLookupResult.mismatch:
        setState(() => _error = 'Мэдээлэл тохирохгүй байна.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Асран хамгаалагчийн эрх идэвхжүүлэх')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Center(child: EduBridgeLogo(size: 64)),
            const SizedBox(height: AppSpacing.sectionSm),
            Text(
              'Асран хамгаалагчийн эрх идэвхжүүлэх',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Утасны дугаар'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Хүүхдийн сурагчийн код',
              ),
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
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Үргэлжлүүлэх'),
            ),
          ],
        ),
      ),
    );
  }
}
