import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';

/// Ангийн удирдсан багш болон хичээл бүрийн багшийг оноох.
class ClassTeacherAssignmentScreen extends StatefulWidget {
  const ClassTeacherAssignmentScreen({
    super.key,
    required this.store,
    this.initialClassId,
  });

  final AppStore store;
  final String? initialClassId;

  @override
  State<ClassTeacherAssignmentScreen> createState() =>
      _ClassTeacherAssignmentScreenState();
}

class _ClassTeacherAssignmentScreenState
    extends State<ClassTeacherAssignmentScreen> {
  String? _classId;
  String? _homeroomTeacherId;
  final Map<int, String?> _subjectTeachers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final classes = widget.store.classes;
    _classId =
        widget.initialClassId ?? (classes.isNotEmpty ? classes.first : null);
    _loadForClass();
  }

  void _loadForClass() {
    final classId = _classId;
    _subjectTeachers.clear();
    if (classId == null) {
      _homeroomTeacherId = null;
      return;
    }
    _homeroomTeacherId = widget.store
        .schoolClassById(classId)
        ?.homeroomTeacherId;
    for (final subject in widget.store.activeSubjects) {
      _subjectTeachers[subject.id] = widget.store.teacherIdForClassSubject(
        classId,
        subject.id,
      );
    }
  }

  Future<void> _save() async {
    final classId = _classId;
    if (classId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveClassAssignments(
        classId: classId,
        homeroomTeacherId: _homeroomTeacherId,
        subjectTeacherIds: Map<int, String?>.from(_subjectTeachers),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Анги, хичээл, багшийн тохиргоо хадгалагдлаа'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assignHomeroomToAll() async {
    if (_homeroomTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Эхлээд анги удирдсан багшийг сонгоно уу'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бүх хичээлд оноох'),
        content: const Text(
          'Анги удирдсан багшийг бүх идэвхтэй хичээлд оноох уу?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Оноох'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final subject in widget.store.activeSubjects) {
        _subjectTeachers[subject.id] = _homeroomTeacherId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final classes = widget.store.classes;
        final teachers = widget.store.activeTeachers;
        final subjects = widget.store.activeSubjects;

        return Scaffold(
          appBar: AppBar(title: const Text('Анги ба багшийн тохиргоо')),
          body: classes.isEmpty
              ? const Center(child: Text('Анги байхгүй'))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _classId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Анги'),
                      items: [
                        for (final name in classes)
                          DropdownMenuItem(
                            value: name,
                            child: Text('$name анги'),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _classId = value;
                          _loadForClass();
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sectionSm),
                    DropdownButtonFormField<String>(
                      key: ValueKey('homeroom-$_classId-$_homeroomTeacherId'),
                      initialValue:
                          _homeroomTeacherId != null &&
                              teachers.any((t) => t.id == _homeroomTeacherId)
                          ? _homeroomTeacherId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Анги удирдсан багш',
                      ),
                      hint: const Text('Багш сонгох'),
                      items: [
                        for (final teacher in teachers)
                          DropdownMenuItem(
                            value: teacher.id,
                            child: Text(
                              teacher.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _homeroomTeacherId = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    OutlinedButton(
                      onPressed: _assignHomeroomToAll,
                      child: const Text(
                        'Бүх хичээлд анги удирдсан багшийг оноох',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    Text(
                      'Хичээлийн багш нар',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    if (subjects.isEmpty)
                      const Text('Идэвхтэй хичээл байхгүй')
                    else
                      for (final subject in subjects) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'subj-${subject.id}-${_subjectTeachers[subject.id]}',
                          ),
                          initialValue:
                              _subjectTeachers[subject.id] != null &&
                                  teachers.any(
                                    (t) => t.id == _subjectTeachers[subject.id],
                                  )
                              ? _subjectTeachers[subject.id]
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: subject.name),
                          hint: const Text('Багш сонгох'),
                          items: [
                            for (final teacher in teachers)
                              DropdownMenuItem(
                                value: teacher.id,
                                child: Text(
                                  teacher.fullName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _subjectTeachers[subject.id] = value;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.gap),
                      ],
                    const SizedBox(height: AppSpacing.sectionSm),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Хадгалж байна…' : 'Тохиргоо хадгалах',
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
