import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  static const _present = 'Ирсэн';
  static const _late = 'Хоцорсон';
  static const _absent = 'Тасалсан';

  @override
  Widget build(BuildContext context) {
    final records = [
      {'date': 'Өнөөдөр', 'status': _present, 'color': Colors.green},
      {'date': '2026 оны 3 сарын 16', 'status': _present, 'color': Colors.green},
      {'date': '2026 оны 3 сарын 15', 'status': _late, 'color': Colors.orange},
      {'date': '2026 оны 3 сарын 14', 'status': _present, 'color': Colors.green},
      {'date': '2026 оны 3 сарын 13', 'status': _absent, 'color': Colors.red},
      {'date': '2026 оны 3 сарын 12', 'status': _present, 'color': Colors.green},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Сүүлийн бүртгэлүүд',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...records.map((record) {
          final color = record['color'] as Color;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(Icons.check_circle, color: color),
              title: Text(record['date'] as String),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record['status'] as String,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
