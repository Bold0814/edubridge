import 'package:flutter/material.dart';

/// Edit / delete actions shown from `...` menu or long-press.
Future<String?> showEditDeleteMenu(
  BuildContext context, {
  bool canEdit = true,
  bool canDelete = true,
}) {
  if (!canEdit && !canDelete) return Future.value(null);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              ListTile(
                title: const Text('✏️ Засах'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (canDelete)
              ListTile(
                title: const Text('🗑 Устгах'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      );
    },
  );
}

/// Shared delete confirmation used by attendance / grades / homework / announcements.
Future<bool> confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Устгах'),
        content: const Text('Та энэ мэдээллийг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Устгах'),
          ),
        ],
      );
    },
  );
  return result == true;
}

void showDeletedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Амжилттай устгалаа.')));
}
