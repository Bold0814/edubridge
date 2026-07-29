import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/school_settings.dart';
import '../navigation/app_navigation.dart';
import '../debug/firestore_debug_log.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_connection_service.dart';
import '../services/firestore_identity_repository.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/admin_permission_gate.dart';
import '../widgets/edubridge_logo.dart';
import 'admin/data_security_screen.dart';
import 'admin/firebase_auth_debug_dialog.dart';
import 'guardian_list_screen.dart';
import 'lesson_periods_settings_screen.dart';
import 'user_account_management_screen.dart';

const _appVersion = '1.0.0';

/// Сургуулийн мэдээлэл болон аппын тохиргоо (давхардсан удирдлагагүй).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _academicYear;
  late String _semester;
  late final TextEditingController _schoolController;
  bool _saving = false;
  bool _checkingFirebase = false;
  bool _checkingFirestoreStructure = false;

  @override
  void initState() {
    super.initState();
    final s = widget.store.schoolSettings;
    _schoolController = TextEditingController(text: s.schoolName);
    _academicYear = SchoolSettings.academicYearOptions.contains(s.academicYear)
        ? s.academicYear
        : SchoolSettings.academicYearOptions.first;
    _semester = SchoolSettings.semesterOptions.contains(s.currentSemester)
        ? s.currentSemester
        : SchoolSettings.semesterOptions.first;
  }

  @override
  void dispose() {
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _saveSchoolInfo() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveSchoolSettings(
        SchoolSettings(
          schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
          schoolName: _schoolController.text.trim(),
          academicYear: _academicYear,
          currentSemester: _semester,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сургуулийн мэдээлэл хадгалагдлаа')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runFirebaseConnectionCheck() async {
    if (!kDebugMode || _checkingFirebase) return;
    setState(() => _checkingFirebase = true);
    try {
      final result = await FirebaseConnectionService()
          .runDebugConnectionCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e, st) {
      debugPrint('Firebase холболт UI алдаа: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(FirebaseConnectionService.failureMessage)),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingFirebase = false);
      }
    }
  }

  Future<void> _runFirestoreStructureCheck() async {
    if (!FirestoreIdentityDebugSetup.isDebugActionEnabled() ||
        _checkingFirestoreStructure) {
      return;
    }
    setState(() => _checkingFirestoreStructure = true);
    try {
      final user = FirebaseAuthService().currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(FirestoreIdentityDebugSetup.notSignedInMessage),
          ),
        );
        return;
      }

      final result = await FirestoreIdentityDebugSetup().run(
        uid: user.uid,
        displayName: user.displayName ?? user.email ?? 'Debug Admin',
        internalEmail: user.email ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e, st) {
      debugLogFirestoreException(
        exception: e,
        stackTrace: st,
        documentPath: '(settings UI catch)',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${FirestoreIdentityDebugSetup.failureMessage}\n$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingFirestoreStructure = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminPermissionGate(
      store: widget.store,
      child: Scaffold(
        appBar: AppBar(title: const Text('Тохиргоо')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.gap,
            AppSpacing.page,
            AppSpacing.section,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.gap),
              child: Column(
                children: [
                  const EduBridgeLogo(size: 56),
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    'EduBridge',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionSm),
            ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) {
                final raw =
                    widget.store.activeSchool?.name ??
                    widget.store.schoolSettings.schoolName;
                final label = raw.trim().isEmpty ? 'Сургууль' : raw.trim();
                return Text(
                  'Сургууль: $label',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sectionSm),

            Text('Сургуулийн мэдээлэл', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.gap),
            TextField(
              controller: _schoolController,
              decoration: const InputDecoration(labelText: 'Сургуулийн нэр'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.gap),
            DropdownButtonFormField<String>(
              initialValue: _academicYear,
              decoration: const InputDecoration(labelText: 'Хичээлийн жил'),
              items: [
                for (final year in SchoolSettings.academicYearOptions)
                  DropdownMenuItem(value: year, child: Text(year)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _academicYear = value);
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            DropdownButtonFormField<String>(
              initialValue: _semester,
              decoration: const InputDecoration(labelText: 'Одоогийн улирал'),
              items: [
                for (final term in SchoolSettings.semesterOptions)
                  DropdownMenuItem(value: term, child: Text(term)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _semester = value);
              },
            ),
            const SizedBox(height: AppSpacing.sectionSm),
            FilledButton(
              onPressed: _saving ? null : _saveSchoolInfo,
              child: Text(_saving ? 'Хадгалж байна…' : 'Хадгалах'),
            ),

            const SizedBox(height: AppSpacing.sectionSm),
            Card(
              child: ListTile(
                title: const Text('Хичээлийн цаг'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LessonPeriodsSettingsScreen(store: widget.store),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.sectionSm),
            Card(
              child: ListTile(
                title: const Text('Хэрэглэгчийн эрх'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserAccountManagementScreen(store: widget.store),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.sectionSm),
            Card(
              child: ListTile(
                title: const Text('Асран хамгаалагчийн холбоос засах'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GuardianListScreen(store: widget.store),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.sectionSm),
            Card(
              color: const Color(0xFFFFF8F8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE57373)),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.security_outlined,
                  color: Color(0xFFC62828),
                ),
                title: const Text('Өгөгдөл ба аюулгүй байдал'),
                subtitle: const Text('Аюултай үйлдлүүд'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DataSecurityScreen(store: widget.store),
                    ),
                  );
                },
              ),
            ),

            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.sectionSm),
              Card(
                child: ListTile(
                  title: const Text('Firebase холболт шалгах'),
                  trailing: _checkingFirebase
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_outlined),
                  onTap: _checkingFirebase ? null : _runFirebaseConnectionCheck,
                ),
              ),
              if (FirebaseAuthService.isDebugAuthCheckEnabled()) ...[
                const SizedBox(height: AppSpacing.sectionSm),
                Card(
                  child: ListTile(
                    title: const Text(FirebaseAuthDebugDialog.title),
                    trailing: const Icon(Icons.lock_outline),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => const FirebaseAuthDebugDialog(),
                      );
                    },
                  ),
                ),
              ],
              if (FirestoreIdentityDebugSetup.isDebugActionEnabled()) ...[
                const SizedBox(height: AppSpacing.sectionSm),
                Card(
                  child: ListTile(
                    title: const Text('Firestore бүтэц шалгах'),
                    trailing: _checkingFirestoreStructure
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.account_tree_outlined),
                    onTap: _checkingFirestoreStructure
                        ? null
                        : _runFirestoreStructureCheck,
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.section),
            Text('Аппын тухай', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.gap),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.card + 4),
                child: Column(
                  children: [
                    const EduBridgeLogo(size: 48),
                    const SizedBox(height: AppSpacing.gap),
                    Text('EduBridge', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'v$_appVersion',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    Text(
                      'ХОЛБОО. ИТГЭЛ. ИРЭЭДҮЙ.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sectionSm),
            OutlinedButton(
              onPressed: () =>
                  AppNavigation.logoutToLogin(context, widget.store),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
              ),
              child: const Text('Гарах'),
            ),
          ],
        ),
      ),
    );
  }
}
