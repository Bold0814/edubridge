import 'package:flutter/material.dart';

import '../../models/school_settings.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import 'create_school_admin_screen.dart';

/// First-time school creation — name only; academic year is set automatically.
class CreateSchoolScreen extends StatefulWidget {
  const CreateSchoolScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CreateSchoolScreen> createState() => _CreateSchoolScreenState();
}

class _CreateSchoolScreenState extends State<CreateSchoolScreen> {
  late final String _schoolId = widget.store.nextSchoolId();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Сургуулийн нэрээ оруулна уу');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final school = await widget.store.createSchool(
        id: _schoolId,
        name: name,
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CreateSchoolAdminScreen(
            store: widget.store,
            schoolId: school.id,
            schoolName: school.name,
          ),
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (e.message) {
          'EMPTY_SCHOOL_NAME' => 'Сургуулийн нэрээ оруулна уу',
          _ => 'Сургууль үүсгэхэд алдаа гарлаа',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Сургууль үүсгэхэд алдаа гарлаа';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Шинэ сургууль')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: EduBridgeLogo(size: 64)),
              const SizedBox(height: AppSpacing.gap),
              Text(
                'Сургуулийн мэдээлэл',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Сургуулийн нэр'),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сургууль үүсгэх'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
