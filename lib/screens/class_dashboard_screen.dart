import 'package:flutter/material.dart';

import '../state/app_store.dart';
import 'class_journal_screen.dart';
import 'student_list_screen.dart';

class ClassDashboardScreen extends StatefulWidget {
  const ClassDashboardScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  @override
  State<ClassDashboardScreen> createState() => _ClassDashboardScreenState();
}

class _ClassDashboardScreenState extends State<ClassDashboardScreen> {
  final List<String> _recentActivities = [
    'Өнөөдрийн ирц бүртгэлээ',
    'Математикийн даалгавар нэмлээ',
    'Эцэг эхийн уулзалтын зарлал',
  ];

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.year} оны ${now.month} сарын ${now.day}';
  }

  void _changeClass() {
    Navigator.pop(context);
  }

  Future<void> _openStudents() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentListScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
  }

  Future<void> _openJournal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassJournalScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.selectedClass} анги',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _changeClass,
              child: const Text('Анги солих'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _todayLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _ActionCard(
          title: 'Сурагчид',
          icon: Icons.groups,
          color: Colors.teal,
          onTap: _openStudents,
        ),
        _ActionCard(
          title: 'Хичээлийн журнал',
          icon: Icons.menu_book,
          color: Colors.indigo,
          onTap: _openJournal,
        ),
        const SizedBox(height: 16),
        Text(
          'Сүүлийн үйл ажиллагаа',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._recentActivities.map((activity) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(Icons.history, color: theme.colorScheme.primary),
              title: Text(activity),
            ),
          );
        }),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
