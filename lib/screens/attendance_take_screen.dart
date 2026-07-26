import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/student.dart';
import '../state/app_store.dart';

class AttendanceTakeScreen extends StatefulWidget {
  const AttendanceTakeScreen({
    super.key,
    required this.selectedClass,
    required this.store,
    this.existing,
    this.lessonDate,
  });

  final String selectedClass;
  final AppStore store;
  final AttendanceRecord? existing;

  /// When set (from journal), attendance is stored for this calendar day.
  final DateTime? lessonDate;

  @override
  State<AttendanceTakeScreen> createState() => _AttendanceTakeScreenState();
}

class _AttendanceTakeScreenState extends State<AttendanceTakeScreen> {
  final Map<String, AttendanceStatus> _statuses = {};

  List<Student> get _students => widget.store.studentsFor(widget.selectedClass);

  @override
  void initState() {
    super.initState();
    _syncStatuses();
    final existing = widget.existing;
    if (existing != null && existing.hasStudentDetails) {
      for (final entry in existing.entries!) {
        for (final student in _students) {
          if (student.fullName == entry.studentName) {
            _statuses[student.id] = entry.status;
          }
        }
      }
    }
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    setState(_syncStatuses);
  }

  void _syncStatuses() {
    final students = _students;
    for (final student in students) {
      _statuses.putIfAbsent(student.id, () => AttendanceStatus.present);
    }
    _statuses.removeWhere(
      (id, _) => students.every((student) => student.id != id),
    );
  }

  String get _dateLabel {
    final existing = widget.existing;
    if (existing != null) return existing.date;
    final day = widget.lessonDate ?? DateTime.now();
    return '${day.year} оны ${day.month} сарын ${day.day}';
  }

  int get _presentCount {
    final ids = _students.map((s) => s.id).toSet();
    return _statuses.entries
        .where(
          (e) => ids.contains(e.key) && e.value == AttendanceStatus.present,
        )
        .length;
  }

  int get _lateCount {
    final ids = _students.map((s) => s.id).toSet();
    return _statuses.entries
        .where((e) => ids.contains(e.key) && e.value == AttendanceStatus.late)
        .length;
  }

  int get _absentCount {
    final ids = _students.map((s) => s.id).toSet();
    return _statuses.entries
        .where((e) => ids.contains(e.key) && e.value == AttendanceStatus.absent)
        .length;
  }

  void _markAllPresent() {
    setState(() {
      for (final student in _students) {
        _statuses[student.id] = AttendanceStatus.present;
      }
    });
  }

  void _setStatus(Student student, AttendanceStatus status) {
    setState(() => _statuses[student.id] = status);
  }

  Future<void> _saveAttendance() async {
    final students = _students;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ ангид сурагч байхгүй байна')),
      );
      return;
    }

    final allSelected = students.every(
      (student) => _statuses.containsKey(student.id),
    );
    if (!allSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бүх сурагчийн төлвийг сонгоно уу')),
      );
      return;
    }

    final entries = students
        .map(
          (student) => StudentAttendanceEntry(
            studentName: student.fullName,
            status: _statuses[student.id] ?? AttendanceStatus.present,
          ),
        )
        .toList();

    final existing = widget.existing;
    final record = AttendanceRecord.detailed(
      id: existing?.id ?? widget.store.nextAttendanceId(),
      date: _dateLabel,
      className: widget.selectedClass,
      entries: entries,
    );

    try {
      if (existing != null) {
        await widget.store.updateAttendance(record);
      } else {
        await widget.store.addAttendance(widget.selectedClass, record);
      }
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ирц амжилттай хадгалагдлаа')));
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final students = _students;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Ирц засах' : 'Өнөөдрийн ирц'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.selectedClass} анги',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Сурагч: ${students.length}'),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: students.isEmpty ? null : _markAllPresent,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Бүгдийг ирсэн болгох'),
                ),
              ],
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('Энэ ангид сурагч байхгүй байна.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final status =
                          _statuses[student.id] ?? AttendanceStatus.present;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StatusChip(
                                    label: AttendanceStatus.present.label,
                                    icon: Icons.check_circle,
                                    color: AttendanceStatus.present.color,
                                    selected:
                                        status == AttendanceStatus.present,
                                    onTap: () => _setStatus(
                                      student,
                                      AttendanceStatus.present,
                                    ),
                                  ),
                                  _StatusChip(
                                    label: AttendanceStatus.late.label,
                                    icon: Icons.schedule,
                                    color: AttendanceStatus.late.color,
                                    selected: status == AttendanceStatus.late,
                                    onTap: () => _setStatus(
                                      student,
                                      AttendanceStatus.late,
                                    ),
                                  ),
                                  _StatusChip(
                                    label: AttendanceStatus.absent.label,
                                    icon: Icons.cancel,
                                    color: AttendanceStatus.absent.color,
                                    selected: status == AttendanceStatus.absent,
                                    onTap: () => _setStatus(
                                      student,
                                      AttendanceStatus.absent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Material(
              elevation: 3,
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _SummaryItem(
                          label: AttendanceStatus.present.label,
                          count: _presentCount,
                          color: AttendanceStatus.present.color,
                        ),
                        _SummaryItem(
                          label: AttendanceStatus.late.label,
                          count: _lateCount,
                          color: AttendanceStatus.late.color,
                        ),
                        _SummaryItem(
                          label: AttendanceStatus.absent.label,
                          count: _absentCount,
                          color: AttendanceStatus.absent.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saveAttendance,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Ирц хадгалах'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : color),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
