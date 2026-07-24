import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../state/app_store.dart';
import 'attendance_detail_screen.dart';
import 'attendance_take_screen.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openTakeScreen(BuildContext context) async {
    await Navigator.push<AttendanceRecord>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AttendanceTakeScreen(selectedClass: selectedClass, store: store),
      ),
    );
  }

  void _openDetail(BuildContext context, AttendanceRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceDetailScreen(
          record: record,
          selectedClass: selectedClass,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final records = store.attendanceFor(selectedClass);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$selectedClass анги',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openTakeScreen(context),
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Өнөөдрийн ирц авах'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Сүүлийн бүртгэлүүд',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...records.map((record) {
              if (record.isLegacy) {
                final color = record.status!.color;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => _openDetail(context, record),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(Icons.check_circle, color: color),
                    title: Text(record.date),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record.status!.label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => _openDetail(context, record),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const Icon(Icons.fact_check, color: Colors.blue),
                  title: Text(record.date),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(record.summaryText),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
