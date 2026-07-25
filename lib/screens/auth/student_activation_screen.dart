import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import 'create_pin_screen.dart';

/// First-time student identity check (student code + linked guardian phone).
class StudentActivationScreen extends StatefulWidget {
  const StudentActivationScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<StudentActivationScreen> createState() =>
      _StudentActivationScreenState();
}

class _StudentActivationScreenState extends State<StudentActivationScreen> {
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final lookup = widget.store.lookupStudentActivation(
      studentCode: _codeController.text,
      guardianPhone: _phoneController.text,
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
      appBar: AppBar(title: const Text('Сурагчийн эрх идэвхжүүлэх')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Center(child: EduBridgeLogo(size: 64)),
            const SizedBox(height: AppSpacing.sectionSm),
            Text(
              'Сурагчийн эрх идэвхжүүлэх',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Сурагчийн код'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Асран хамгаалагчийн утас',
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
