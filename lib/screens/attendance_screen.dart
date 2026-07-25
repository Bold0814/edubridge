import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
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

  Future<void> _openTakeScreen(
    BuildContext context, {
    AttendanceRecord? existing,
  }) async {
    await Navigator.push<AttendanceRecord>(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceTakeScreen(
          selectedClass: selectedClass,
          store: store,
          existing: existing,
        ),
      ),
    );
    if (!context.mounted) return;
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

  Future<void> _onMenuSelected(
    BuildContext context,
    AttendanceRecord record,
    String action,
  ) async {
    if (action == 'edit') {
      await _openTakeScreen(context, existing: record);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDelete(context);
      if (!ok) return;
      await store.deleteAttendance(selectedClass, record.id);
      if (!context.mounted) return;
      showDeletedSnackBar(context);
    }
  }

  Future<void> _onLongPress(
    BuildContext context,
    AttendanceRecord record,
  ) async {
    final action = await showEditDeleteMenu(context);
    if (action == null || !context.mounted) return;
    await _onMenuSelected(context, record, action);
  }

  Widget _menu(BuildContext context, AttendanceRecord record) {
    return PopupMenuButton<String>(
      tooltip: 'Цэс',
      onSelected: (value) => _onMenuSelected(context, record, value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('✏️ Засах')),
        PopupMenuItem(value: 'delete', child: Text('🗑 Устгах')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final records = store.attendanceFor(selectedClass);
        final isEmpty = records.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('$selectedClass · Ирц'),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openTakeScreen(context),
            tooltip: 'Ирц авах',
            child: const Icon(Icons.add),
          ),
          body: isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Text(
                      'Ирцийн бүртгэл байхгүй байна',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    88,
                  ),
                  children: [
                    Text(
                      'Сүүлийн бүртгэлүүд',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    ...records.map((record) {
                      if (record.isLegacy) {
                        final color = record.status!.color;
                        return Card(
                          child: ListTile(
                            onTap: () => _openDetail(context, record),
                            onLongPress: () => _onLongPress(context, record),
                            leading: Icon(Icons.check_circle, color: color),
                            title: Text(record.date),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  record.status!.label,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _menu(context, record),
                              ],
                            ),
                          ),
                        );
                      }

                      return Card(
                        child: ListTile(
                          onTap: () => _openDetail(context, record),
                          onLongPress: () => _onLongPress(context, record),
                          leading: const Icon(
                            Icons.fact_check,
                            color: AppColors.primary,
                          ),
                          title: Text(record.date),
                          subtitle: Text(record.summaryText),
                          trailing: _menu(context, record),
                        ),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }
}
