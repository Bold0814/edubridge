import 'package:flutter/material.dart';

import '../models/timetable.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/admin_permission_gate.dart';
import '../widgets/confirm_delete.dart';

/// Settings: CRUD for school-wide lesson periods (Хичээлийн цаг).
class LessonPeriodsSettingsScreen extends StatelessWidget {
  const LessonPeriodsSettingsScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {LessonPeriod? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _LessonPeriodFormScreen(store: store, existing: existing),
      ),
    );
  }

  Future<void> _delete(BuildContext context, LessonPeriod period) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Цаг устгах'),
          content: Text(
            '${period.periodNumber}-р цагийг устгавал холбоотой хуваарь мөн устана.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Устгах'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await store.deleteLessonPeriod(period.id);
    if (!context.mounted) return;
    showDeletedSnackBar(context);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPermissionGate(
      store: store,
      child: Scaffold(
        appBar: AppBar(title: const Text('Хичээлийн цаг')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openForm(context),
          child: const Icon(Icons.add),
        ),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final periods = store.lessonPeriods;
            if (periods.isEmpty) {
              return const Center(child: Text('Хичээлийн цаг бүртгэгдээгүй'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: periods.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.item),
              itemBuilder: (context, index) {
                final period = periods[index];
                return Card(
                  child: ListTile(
                    title: Text('${period.periodNumber}-р цаг'),
                    subtitle: Text(period.timeLabel),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _openForm(context, existing: period);
                        } else if (value == 'delete') {
                          await _delete(context, period);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Засах')),
                        PopupMenuItem(value: 'delete', child: Text('Устгах')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LessonPeriodFormScreen extends StatefulWidget {
  const _LessonPeriodFormScreen({required this.store, this.existing});

  final AppStore store;
  final LessonPeriod? existing;

  @override
  State<_LessonPeriodFormScreen> createState() =>
      _LessonPeriodFormScreenState();
}

class _LessonPeriodFormScreenState extends State<_LessonPeriodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _numberController = TextEditingController(
      text: existing == null ? '' : '${existing.periodNumber}',
    );
    _startController = TextEditingController(text: existing?.startTime ?? '');
    _endController = TextEditingController(text: existing?.endTime ?? '');
  }

  @override
  void dispose() {
    _numberController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    var hour = 8;
    var minute = 0;
    if (parts.length == 2) {
      hour = int.tryParse(parts[0]) ?? 8;
      minute = int.tryParse(parts[1]) ?? 0;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return;
    final h = picked.hour.toString().padLeft(2, '0');
    final m = picked.minute.toString().padLeft(2, '0');
    setState(() => controller.text = '$h:$m');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final number = int.parse(_numberController.text.trim());
    final period = LessonPeriod(
      id: widget.existing?.id ?? widget.store.nextLessonPeriodId(),
      schoolId: widget.store.activeSchoolId ?? AppStore.defaultSchoolId,
      periodNumber: number,
      startTime: _startController.text.trim(),
      endTime: _endController.text.trim(),
    );
    if (widget.existing != null) {
      await widget.store.updateLessonPeriod(period);
    } else {
      await widget.store.addLessonPeriod(period);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Хичээлийн цаг хадгалагдлаа.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Цаг засах' : 'Шинэ хичээлийн цаг',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Цагийн дугаар',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final n = int.tryParse(value?.trim() ?? '');
                if (n == null || n < 1) return 'Зөв дугаар оруулна уу';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextFormField(
              controller: _startController,
              readOnly: true,
              onTap: () => _pickTime(_startController),
              decoration: InputDecoration(
                labelText: 'Эхлэх цаг',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () => _pickTime(_startController),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Эхлэх цаг сонгоно уу';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.gap),
            TextFormField(
              controller: _endController,
              readOnly: true,
              onTap: () => _pickTime(_endController),
              decoration: InputDecoration(
                labelText: 'Дуусах цаг',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () => _pickTime(_endController),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Дуусах цаг сонгоно уу';
                }
                return null;
              },
            ),
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
