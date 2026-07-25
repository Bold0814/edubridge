import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/admin_permission_gate.dart';

/// Admin-only: create pending login accounts for an existing student.
class StudentLoginProvisionScreen extends StatefulWidget {
  const StudentLoginProvisionScreen({
    super.key,
    required this.store,
    required this.studentId,
  });

  final AppStore store;
  final String studentId;

  @override
  State<StudentLoginProvisionScreen> createState() =>
      _StudentLoginProvisionScreenState();
}

class _StudentLoginProvisionScreenState
    extends State<StudentLoginProvisionScreen> {
  bool _saving = false;
  String? _generatedCode;

  bool get _guardianAccountExists {
    final guardian = widget.store.primaryGuardianForStudent(widget.studentId);
    if (guardian == null) return false;
    return widget.store.findGuardianAccountByNormalizedPhone(guardian.phone) !=
        null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final student = await widget.store.provisionLoginForExistingStudent(
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() => _generatedCode = student.studentCode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нэвтрэх эрх үүсгэлээ (идэвхжүүлэх хүлээгдэж байна).'),
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'STUDENT_ACCOUNT_EXISTS' => 'Сурагчид нэвтрэх эрх бүртгэлтэй байна.',
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
    final theme = Theme.of(context);
    final student = widget.store.studentById(widget.studentId);
    final existingCode = student?.studentCode;

    return AdminPermissionGate(
      store: widget.store,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Нэвтрэх эрх үүсгэх'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              'Сурагч болон асран хамгаалагчийн нэвтрэх эрхийг pending төлөвт үүсгэнэ. PIN-ийг админ тохируулахгүй.',
              style: theme.textTheme.bodyMedium,
            ),
            if (existingCode != null && existingCode.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Сурагчийн код: $existingCode',
                style: theme.textTheme.titleMedium,
              ),
            ],
            if (_generatedCode != null) ...[
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Сурагчийн код: $_generatedCode',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.gap),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _generatedCode!));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Код хууллаа.')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Хуулах'),
              ),
            ],
            if (_guardianAccountExists) ...[
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Энэ утсанд нэвтрэх эрх бүртгэлтэй байна.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
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
              onPressed: _saving || _generatedCode != null ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Үүсгэх'),
            ),
          ),
        ),
      ),
    );
  }
}
