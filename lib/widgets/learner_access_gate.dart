import 'package:flutter/material.dart';

import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';

/// Ensures guardian/student portal routes only show authorized learner data.
class LearnerAccessGate extends StatelessWidget {
  const LearnerAccessGate({
    super.key,
    required this.store,
    required this.student,
    required this.child,
  });

  final AppStore store;
  final Student student;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (store.canViewLearnerStudent(student.id)) {
      return child;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Эрхгүй'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Буцах',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: Text(
            'Энэ мэдээллийг харах эрхгүй байна.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
