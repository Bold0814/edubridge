import 'package:flutter/material.dart';

import '../../models/school_data_reset.dart';
import '../../services/school_data_reset/school_data_reset_service.dart';
import '../../services/school_data_reset/sqlite_school_data_reset_repository.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin_permission_gate.dart';
import '../onboarding/school_setup_screen.dart';
import 'admin_school_home_screen.dart';

/// Admin flow: options → preview → double confirm → transactional reset.
class TestDataResetScreen extends StatefulWidget {
  const TestDataResetScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TestDataResetScreen> createState() => _TestDataResetScreenState();
}

class _TestDataResetScreenState extends State<TestDataResetScreen> {
  late final SchoolDataResetService _service;
  SchoolResetScope _scope = const SchoolResetScope();
  ResetPreview? _preview;
  String? _previewError;
  bool _loadingPreview = true;
  bool _submitting = false;

  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _service = SchoolDataResetService(
      store: widget.store,
      repository: SqliteSchoolDataResetRepository(
        widget.store.repository.database,
      ),
    );
    _confirmController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });
    try {
      final preview = await _service.getPreview();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewError = e.toString();
        _loadingPreview = false;
      });
    }
  }

  bool get _canSubmitPrimary => !_submitting && _scope.hasAnySelection;

  Future<void> _onContinuePressed() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Анхааруулга'),
        content: const Text(
          'Энэ үйлдлийг буцаах боломжгүй. Сонгосон мэдээлэл бүрмөсөн устна.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Үргэлжлүүлэх'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    await _showSecondConfirmation();
  }

  Future<void> _showSecondConfirmation() async {
    _confirmController.clear();
    _passwordController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: !_submitting,
      enableDrag: !_submitting,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.page,
            right: AppSpacing.page,
            top: AppSpacing.page,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.page,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              void refresh() => setModalState(() {});
              _confirmController.removeListener(refresh);
              _passwordController.removeListener(refresh);
              _confirmController.addListener(refresh);
              _passwordController.addListener(refresh);

              final phraseOk = _service.isConfirmationPhraseValid(
                _confirmController.text,
              );
              final canSubmit =
                  !_submitting &&
                  phraseOk &&
                  _passwordController.text.isNotEmpty;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Эцсийн баталгаажуулалт',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  TextField(
                    controller: _confirmController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'Баталгаажуулахын тулд УСТГАХ гэж бичнэ үү.',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  TextField(
                    controller: _passwordController,
                    enabled: !_submitting,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Админ нууц үг',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setModalState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionSm),
                  FilledButton(
                    onPressed: canSubmit ? () => _executeReset(context) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Бүрмөсөн устгах'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _executeReset(BuildContext sheetContext) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await _service.resetOperationalData(
        scope: _scope,
        confirmationPhrase: _confirmController.text,
        adminPassword: _passwordController.text,
      );
      if (!mounted) return;
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Туршилтын өгөгдөл амжилттай цэвэрлэгдлээ.'),
        ),
      );
      final incomplete = widget.store.isSchoolSetupIncomplete;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => incomplete
              ? SchoolSetupScreen(store: widget.store)
              : AdminSchoolHomeScreen(store: widget.store),
        ),
        (route) => false,
      );
    } on SchoolResetValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on SchoolResetPermissionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Мэдээллийг бүрэн устгаж чадсангүй. Өөрчлөлт хийгдээгүй.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_submitting,
      child: AdminPermissionGate(
        store: widget.store,
        child: Scaffold(
          appBar: AppBar(title: const Text('Туршилтын өгөгдөл цэвэрлэх')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text('Устгах хэсэг', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.item),
              CheckboxListTile(
                value: _scope.structurePeople,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() {
                        _scope = _scope.copyWith(structurePeople: v ?? false);
                      }),
                title: const Text('Багш, анги, сурагчийн мэдээлэл'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _scope.academicRecords,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() {
                        _scope = _scope.copyWith(academicRecords: v ?? false);
                      }),
                title: const Text('Ирц, дүн, даалгавар'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _scope.journalAndComms,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() {
                        _scope = _scope.copyWith(journalAndComms: v ?? false);
                      }),
                title: const Text('Журнал, зарлал, тэмдэглэл'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _scope.scheduleAndAssignments,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() {
                        _scope = _scope.copyWith(
                          scheduleAndAssignments: v ?? false,
                        );
                      }),
                title: const Text('Хуваарь болон оноолт'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _scope.resetSchoolSettings,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() {
                        _scope = _scope.copyWith(
                          resetSchoolSettings: v ?? false,
                        );
                      }),
                title: const Text('Сургуулийн үндсэн тохиргоог шинэчлэх'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Text('Устгагдах мэдээлэл', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.item),
              if (_loadingPreview)
                const Center(child: CircularProgressIndicator())
              else if (_previewError != null)
                Text(
                  _previewError!,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              else if (_preview != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.card),
                    child: Column(
                      children: [
                        for (final entry in _preview!.labeledCounts.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.key)),
                                Text(
                                  '${entry.value}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.section),
              FilledButton(
                onPressed: _canSubmitPrimary ? _onContinuePressed : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Үргэлжлүүлэх'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
