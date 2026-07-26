import 'package:flutter/material.dart';

import '../services/journal_schedule_service.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

/// Lists scheduled / persisted journal occurrences for one class-subject.
class JournalHistoryScreen extends StatelessWidget {
  const JournalHistoryScreen({
    super.key,
    required this.store,
    required this.classId,
    required this.subjectId,
    this.teacherId,
  });

  final AppStore store;
  final String classId;
  final int subjectId;
  final String? teacherId;

  @override
  Widget build(BuildContext context) {
    final subject = store.subjectById(subjectId);
    final timeline = JournalScheduleService.buildTimeline(
      store,
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId,
    ).reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${subject?.name ?? 'Хичээл'} · Журналын түүх'),
        centerTitle: true,
      ),
      body: timeline.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.page),
                child: Text(
                  'Журналын түүх хоосон байна.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: timeline.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final lesson = timeline[index];
                final occurrence = store.findLessonOccurrence(
                  classId: classId,
                  subjectId: subjectId,
                  lessonDate: lesson.lessonDate,
                  periodId: lesson.periodId,
                );
                final attendance = store
                    .attendanceFor(classId)
                    .where((r) => r.isOnCalendarDay(lesson.lessonDate))
                    .toList();
                final status = attendance.isEmpty
                    ? 'Ирц бүртгээгүй'
                    : 'Ирц бүртгэсэн';
                final topic = occurrence?.topic?.trim();
                return Card(
                  child: ListTile(
                    title: Text(
                      JournalScheduleService.mongolianDateLabel(
                        lesson.lessonDate,
                      ),
                    ),
                    subtitle: Text(
                      [
                        '${lesson.periodNumber}-р цаг · ${lesson.timeLabel}',
                        if (topic != null && topic.isNotEmpty) topic,
                        status,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, lesson),
                  ),
                );
              },
            ),
    );
  }
}
