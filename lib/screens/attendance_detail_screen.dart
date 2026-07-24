import 'package:flutter/material.dart';

import '../models/attendance_record.dart';

class AttendanceDetailScreen extends StatelessWidget {
  const AttendanceDetailScreen({super.key, required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classLabel = record.className.isEmpty
        ? 'Анги'
        : '${record.className} анги';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ирцийн дэлгэрэнгүй'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            classLabel,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(record.date, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (record.hasStudentDetails) ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: 'Ирсэн',
                  count: record.presentCount,
                  color: Colors.green,
                ),
                _SummaryChip(
                  label: 'Хоцорсон',
                  count: record.lateCount,
                  color: Colors.orange,
                ),
                _SummaryChip(
                  label: 'Тасалсан',
                  count: record.absentCount,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...record.entries!.map((entry) {
              final color = entry.status.color;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    entry.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                      entry.status.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Энэ хуучин бүртгэлийн сурагчдын дэлгэрэнгүй мэдээлэл байхгүй байна',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
