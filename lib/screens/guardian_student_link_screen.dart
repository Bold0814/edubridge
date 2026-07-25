import 'package:flutter/material.dart';

import '../models/guardian.dart';
import '../models/guardian_student.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

class GuardianStudentLinkScreen extends StatefulWidget {
  const GuardianStudentLinkScreen({
    super.key,
    required this.store,
    required this.guardian,
  });

  final AppStore store;
  final Guardian guardian;

  @override
  State<GuardianStudentLinkScreen> createState() =>
      _GuardianStudentLinkScreenState();
}

class _GuardianStudentLinkScreenState extends State<GuardianStudentLinkScreen> {
  late final Map<String, String> _relationships;
  late final Set<String> _selectedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.store.linksForGuardian(widget.guardian.id);
    _selectedIds = {for (final l in existing) l.studentId};
    _relationships = {for (final l in existing) l.studentId: l.relationship};
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final links = <GuardianStudent>[
        for (final id in _selectedIds)
          GuardianStudent(
            guardianId: widget.guardian.id,
            studentId: id,
            relationship:
                _relationships[id] ?? GuardianStudent.relationshipOptions.first,
          ),
      ];
      await widget.store.saveGuardianStudentLinks(
        guardianId: widget.guardian.id,
        links: links,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хүүхдийн холбоос хадгалагдлаа')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.store.allStudents;

    return Scaffold(
      appBar: AppBar(title: Text(widget.guardian.fullName)),
      body: students.isEmpty
          ? const Center(child: Text('Сурагч байхгүй'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Text(
                  'Хүүхдүүд',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.gap),
                for (final student in students) ...[
                  Card(
                    child: CheckboxListTile(
                      value: _selectedIds.contains(student.id),
                      title: Text('${student.fullName} (${student.className})'),
                      subtitle: _selectedIds.contains(student.id)
                          ? DropdownButton<String>(
                              value:
                                  _relationships[student.id] ??
                                  GuardianStudent.relationshipOptions.first,
                              isExpanded: true,
                              items: [
                                for (final rel
                                    in GuardianStudent.relationshipOptions)
                                  DropdownMenuItem(
                                    value: rel,
                                    child: Text(rel),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _relationships[student.id] = value;
                                });
                              },
                            )
                          : null,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedIds.add(student.id);
                            _relationships.putIfAbsent(
                              student.id,
                              () => GuardianStudent.relationshipOptions.first,
                            );
                          } else {
                            _selectedIds.remove(student.id);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                ],
                const SizedBox(height: AppSpacing.sectionSm),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Хадгалж байна…' : 'Хадгалах'),
                ),
              ],
            ),
    );
  }
}
