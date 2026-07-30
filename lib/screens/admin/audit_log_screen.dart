import 'package:flutter/material.dart';

import '../../models/audit_log.dart';
import '../../services/app_clock.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';

/// Read-only audit trail. No edit/delete actions.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String? _dateKey;
  String? _classId;
  String? _teacherId;
  AuditAction? _action;
  AuditEntityType? _entityType;

  AppStore get store => widget.store;

  Future<void> _pickDate() async {
    final now = AppClock.now();
    final initial = _dateKey == null
        ? now
        : (DateTime.tryParse(_dateKey!) ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _dateKey = AppClock.formatDateKey(picked));
  }

  String _classLabel(String? classId) {
    if (classId == null || classId.isEmpty) return '';
    return store.schoolClassById(classId)?.name ?? classId;
  }

  String _subjectLabel(int? subjectId) {
    if (subjectId == null) return '';
    return store.subjectById(subjectId)?.name ?? '';
  }

  String _timeLabel(AuditLogEntry entry) {
    final dt = entry.createdAtDate;
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _teacherLabel(AuditLogEntry entry) {
    final name = entry.teacherName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = entry.teacherId;
    if (id == null || id.isEmpty) return 'Багш';
    return store.teacherById(id)?.fullName ?? 'Багш';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.canViewAuditLogs) {
          return Scaffold(
            appBar: AppBar(title: const Text('Үйлдлийн түүх')),
            body: const Center(child: Text('Энэ хэсэгт хандах эрхгүй.')),
          );
        }

        final classes = store.schoolClasses;
        final teachers = store.activeTeachers;
        final logs = store.auditLogsVisible(
          dateKey: _dateKey,
          classId: _classId,
          teacherId: _teacherId,
          action: _action,
          entityType: _entityType,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Үйлдлийн түүх')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Wrap(
                spacing: AppSpacing.itemSm,
                runSpacing: AppSpacing.itemSm,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _dateKey == null
                          ? 'Огноо'
                          : AppClock.displayLabel(_dateKey!),
                    ),
                  ),
                  if (_dateKey != null)
                    TextButton(
                      onPressed: () => setState(() => _dateKey = null),
                      child: const Text('Огноо цэвэрлэх'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.itemSm),
              DropdownButtonFormField<String?>(
                initialValue: _classId,
                decoration: const InputDecoration(labelText: 'Анги'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Бүгд'),
                  ),
                  for (final c in classes)
                    DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                ],
                onChanged: (value) => setState(() => _classId = value),
              ),
              const SizedBox(height: AppSpacing.itemSm),
              DropdownButtonFormField<String?>(
                initialValue: _teacherId,
                decoration: const InputDecoration(labelText: 'Багш'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Бүгд'),
                  ),
                  for (final t in teachers)
                    DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.fullName),
                    ),
                ],
                onChanged: (value) => setState(() => _teacherId = value),
              ),
              const SizedBox(height: AppSpacing.itemSm),
              DropdownButtonFormField<AuditAction?>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'Үйлдлийн төрөл'),
                items: [
                  const DropdownMenuItem<AuditAction?>(
                    value: null,
                    child: Text('Бүгд'),
                  ),
                  for (final a in AuditAction.values)
                    DropdownMenuItem<AuditAction?>(
                      value: a,
                      child: Text(a.labelMn),
                    ),
                ],
                onChanged: (value) => setState(() => _action = value),
              ),
              const SizedBox(height: AppSpacing.itemSm),
              DropdownButtonFormField<AuditEntityType?>(
                initialValue: _entityType,
                decoration: const InputDecoration(labelText: 'Entity төрөл'),
                items: [
                  const DropdownMenuItem<AuditEntityType?>(
                    value: null,
                    child: Text('Бүгд'),
                  ),
                  for (final e in AuditEntityType.values)
                    DropdownMenuItem<AuditEntityType?>(
                      value: e,
                      child: Text(e.labelMn),
                    ),
                ],
                onChanged: (value) => setState(() => _entityType = value),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Үйлдлийн түүх хоосон байна.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final entry in logs) ...[
                  _AuditLogTile(
                    time: _timeLabel(entry),
                    teacher: _teacherLabel(entry),
                    className: _classLabel(entry.classId),
                    subjectName: _subjectLabel(entry.subjectId),
                    actionTitle: entry.actionTitle,
                    valueChange: entry.valueChangeLabel,
                  ),
                  const SizedBox(height: AppSpacing.itemSm),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({
    required this.time,
    required this.teacher,
    required this.className,
    required this.subjectName,
    required this.actionTitle,
    required this.valueChange,
  });

  final String time;
  final String teacher;
  final String className;
  final String subjectName;
  final String actionTitle;
  final String? valueChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(teacher, style: theme.textTheme.titleSmall),
              if (className.isNotEmpty || subjectName.isNotEmpty)
                Text(
                  [
                    if (className.isNotEmpty) className,
                    if (subjectName.isNotEmpty) subjectName,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              Text(actionTitle, style: theme.textTheme.bodyMedium),
              if (valueChange != null && valueChange!.isNotEmpty)
                Text(
                  valueChange!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
