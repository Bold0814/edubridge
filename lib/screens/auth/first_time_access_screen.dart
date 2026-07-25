import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/edubridge_logo.dart';
import 'guardian_activation_screen.dart';
import 'student_activation_screen.dart';

/// Chooses guardian vs student first-time activation.
class FirstTimeAccessScreen extends StatelessWidget {
  const FirstTimeAccessScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Анх удаа нэвтрэх')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: EduBridgeLogo(size: 72)),
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Анх удаа нэвтрэх',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.itemSm),
              Text(
                'Таны эрхийг идэвхжүүлэхийн тулд төрлөө сонгоно уу.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.section),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          GuardianActivationScreen(store: store),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Асран хамгаалагч'),
              ),
              const SizedBox(height: AppSpacing.gap),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          StudentActivationScreen(store: store),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Сурагч'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
