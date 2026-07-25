import 'package:flutter/material.dart';

import '../models/timetable.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';

/// Settings: assign subject to class + weekday + period (Хичээлийн хуваарь).
class ClassTimetableSettingsScreen extends StatefulWidget {
  const ClassTimetableSettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ClassTimetableSettingsScreen> createState() =>
      _ClassTimetableSettingsScreenState();
}

class _ClassTimetableSettingsScreenState
    extends State<ClassTimetableSettingsScreen> {
  String? _classId;
  int _weekday = DateTime.monday;

  @override
  void initState() {
    super.initState();
    final classes = widget.store.classes;
    if (classes.isNotEmpty) _classId = classes.first;
  }

  Future<void> _openForm({ClassTimetable? existing}) async {
    final classId = _classId;
    if (classId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TimetableSlotFormScreen(
          store: widget.store,
          classId: classId,
          weekday: _weekday,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _delete(ClassTimetable entry) async {
    final ok = await confirmDelete(context);
    if (!ok) return;
    await widget.store.deleteClassTimetable(entry.id);
    if (!mounted) return;
    showDeletedSnackBar(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classes = widget.store.classes;

    return Scaffold(
      appBar: AppBar(title: const Text('Хичээлийн хуваарь')),
      floatingActionButton: FloatingActionButton(
        onPressed: _classId == null ? null : () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final periods = widget.store.lessonPeriods;
          final classId = _classId;
          final entries = classId == null
              ? const <ClassTimetable>[]
              : widget.store.timetableForClassWeekday(classId, _weekday);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration: const InputDecoration(labelText: 'Анги'),
                items: [
                  for (final name in classes)
                    DropdownMenuItem(value: name, child: Text('$name анги')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _classId = value);
                },
              ),
              const SizedBox(height: AppSpacing.gap),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Гариг'),
                items: [
                  for (final day in TimetableWeekday.schoolDays)
                    DropdownMenuItem(
                      value: day,
                      child: Text(TimetableWeekday.label(day)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _weekday = value);
                },
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              if (periods.isEmpty)
                const Text(
                  'Эхлээд Тохиргоо → Хичээлийн цаг хэсэгт цаг нэмнэ үү.',
                )
              else if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Энэ өдөр хуваарь байхгүй')),
                )
              else
                ...entries.map((entry) {
                  final period = widget.store.periodById(entry.periodId);
                  final subject = widget.store.subjectById(entry.subjectId);
                  final teacher = widget.store.teacherForClassSubject(
                    entry.classId,
                    entry.subjectId,
                  );
                  return Card(
                    child: ListTile(
                      title: Text(
                        period == null
                            ? 'Цаг'
                            : '${period.periodNumber}-р цаг · ${period.timeLabel}',
                      ),
                      subtitle: Text(
                        [
                          subject?.name ?? 'Хичээл',
                          if (teacher != null) teacher.fullName,
                        ].join(' · '),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _openForm(existing: entry);
                          } else if (value == 'delete') {
                            await _delete(entry);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Засах')),
                          PopupMenuItem(value: 'delete', child: Text('Устгах')),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.section),
              Text(
                'Багш автоматаар анги + хичээлийн оноолтоос тодорхойлогдоно.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimetableSlotFormScreen extends StatefulWidget {
  const _TimetableSlotFormScreen({
    required this.store,
    required this.classId,
    required this.weekday,
    this.existing,
  });

  final AppStore store;
  final String classId;
  final int weekday;
  final ClassTimetable? existing;

  @override
  State<_TimetableSlotFormScreen> createState() =>
      _TimetableSlotFormScreenState();
}

class _TimetableSlotFormScreenState extends State<_TimetableSlotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _periodId;
  int? _subjectId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final periods = widget.store.lessonPeriods;
    final subjects = widget.store.activeSubjects;
    if (existing != null) {
      _periodId = existing.periodId;
      _subjectId = existing.subjectId;
    } else {
      if (periods.isNotEmpty) _periodId = periods.first.id;
      if (subjects.isNotEmpty) _subjectId = subjects.first.id;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final periodId = _periodId;
    final subjectId = _subjectId;
    if (periodId == null || subjectId == null) {
      setState(() => _error = 'Цаг болон хичээл сонгоно уу');
      return;
    }

    final entry = ClassTimetable(
      id: widget.existing?.id ?? widget.store.nextClassTimetableId(),
      classId: widget.classId,
      weekday: widget.weekday,
      periodId: periodId,
      subjectId: subjectId,
    );

    try {
      if (widget.existing != null) {
        await widget.store.updateClassTimetable(entry);
      } else {
        await widget.store.addClassTimetable(entry);
      }
    } on ArgumentError catch (e) {
      setState(() {
        _error = e.message == 'SLOT_TAKEN'
            ? 'Энэ цагт хуваарь аль хэдийн байна'
            : '${e.message}';
      });
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Хуваарь хадгалагдлаа.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final periods = widget.store.lessonPeriods;
    final subjects = widget.store.activeSubjects;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Хуваарь засах' : 'Хуваарь нэмэх',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              '${widget.classId} · ${TimetableWeekday.label(widget.weekday)}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.gap),
            DropdownButtonFormField<String>(
              initialValue: _periodId,
              decoration: const InputDecoration(
                labelText: 'Цаг',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final period in periods)
                  DropdownMenuItem(
                    value: period.id,
                    child: Text(
                      '${period.periodNumber}-р · ${period.timeLabel}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _periodId = value),
              validator: (value) {
                if (value == null) return 'Цаг сонгоно уу';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            DropdownButtonFormField<int>(
              initialValue: _subjectId,
              decoration: const InputDecoration(
                labelText: 'Хичээл',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final subject in subjects)
                  DropdownMenuItem(
                    value: subject.id,
                    child: Text(subject.name),
                  ),
              ],
              onChanged: (value) => setState(() => _subjectId = value),
              validator: (value) {
                if (value == null) return 'Хичээл сонгоно уу';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.gap),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.sectionSm),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Хадгалах'),
            ),
          ],
        ),
      ),
    );
  }
}
