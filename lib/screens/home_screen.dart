import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../models/teacher_assigned_class.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/edubridge_logo.dart';
import '../widgets/session_menu_button.dart';
import 'class_dashboard_screen.dart';

/// Class workspace shell — dashboard hub (creation happens in destination screens).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _selectedClass;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.selectedClass;
  }

  Future<void> _onClassChanged(String classId) async {
    final access = widget.store.assignedClassForActiveTeacher(classId);
    if (access == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ ангид хандах эрхгүй байна.')),
      );
      return;
    }

    var preferred = widget.store.activeContext.subjectId;
    if (access.subjects.length > 1) {
      final belongs =
          preferred != null && access.subjects.any((s) => s.id == preferred);
      if (!belongs) {
        preferred = await _pickSubject(access);
        if (preferred == null) return;
      }
    }

    final ok = await widget.store.selectTeacherDashboardClass(
      classId,
      preferredSubjectId: preferred,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ ангид хандах эрхгүй байна.')),
      );
      return;
    }
    setState(() => _selectedClass = classId);
  }

  Future<int?> _pickSubject(TeacherAssignedClass access) async {
    return showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('${access.className} · Хичээл сонгох'),
          children: [
            for (final Subject subject in access.subjects)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, subject.id),
                child: Text(subject.name),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EduBridgeLogo(size: 30),
              SizedBox(width: 8),
              Text('EduBridge'),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Буцах',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [SessionMenuButton(store: widget.store)],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final assigned = widget.store.assignedClassesForActiveTeacher();
          if (assigned.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.page),
                child: Text(
                  'Танд хуваарилсан анги алга байна.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!widget.store.teacherCanAccessClass(_selectedClass)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.page),
                child: Text(
                  'Энэ ангид хандах эрхгүй байна.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ClassDashboardScreen(
            selectedClass: _selectedClass,
            store: widget.store,
            onClassChanged: _onClassChanged,
          );
        },
      ),
    );
  }
}
