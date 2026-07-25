import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_spacing.dart';

/// Blocks non-admin users from school-administration screens.
class AdminPermissionGate extends StatelessWidget {
  const AdminPermissionGate({
    super.key,
    required this.store,
    required this.child,
  });

  final AppStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (store.hasAdminPermissionForActiveSchool) {
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
            'Энэ үйлдлийг хийх эрхгүй байна.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
