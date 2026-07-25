import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/developer_tools_screen.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import '../widgets/edubridge_logo.dart';
import '../widgets/session_menu_button.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class ClassSelectionScreen extends StatelessWidget {
  const ClassSelectionScreen({super.key, required this.store});

  final AppStore store;

  void _openDeveloperTools(BuildContext context) {
    if (!kDebugMode) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DeveloperToolsScreen(store: store, repository: store.repository),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(store: store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: kDebugMode
            ? _BrandedTitle(
                onLongPressDevTools: () => _openDeveloperTools(context),
              )
            : const _BrandedTitle(),
        centerTitle: true,
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Тест хэрэгсэл',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => _openDeveloperTools(context),
            ),
          if (store.hasAdminPermissionForActiveSchool)
            IconButton(
              tooltip: 'Тохиргоо',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _openSettings(context),
            ),
          SessionMenuButton(store: store),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final classes = store.classes;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                'Ажиллах ангиа сонгоно уу',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              ...classes.map((className) {
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(
                            selectedClass: className,
                            store: store,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.class_,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.gap),
                          Expanded(
                            child: Text(
                              '$className анги',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// Compact AppBar brand: [logo] EduBridge.
class _BrandedTitle extends StatefulWidget {
  const _BrandedTitle({this.onLongPressDevTools});

  final VoidCallback? onLongPressDevTools;

  @override
  State<_BrandedTitle> createState() => _BrandedTitleState();
}

class _BrandedTitleState extends State<_BrandedTitle> {
  Timer? _holdTimer;

  void _onLongPressStart(LongPressStartDetails _) {
    final open = widget.onLongPressDevTools;
    if (open == null) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), open);
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _cancelHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EduBridgeLogo(size: 30),
        SizedBox(width: 8),
        Text('EduBridge'),
      ],
    );

    if (widget.onLongPressDevTools == null) return content;

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      child: content,
    );
  }
}
