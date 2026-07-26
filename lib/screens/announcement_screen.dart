import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
import 'announcement_create_screen.dart';
import 'announcement_detail_screen.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  Future<void> _openCreateScreen(
    BuildContext context, {
    Announcement? existing,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementCreateScreen(
          className: selectedClass,
          store: store,
          existing: existing,
        ),
      ),
    );
    if (!context.mounted) return;
    if (saved == true) {
      // Store already notified; ListenableBuilder refreshes.
    }
  }

  Future<void> _openDetail(BuildContext context, Announcement item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementDetailScreen(
          store: store,
          announcement: item,
          showReceiptStats: true,
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    Announcement item,
    String action,
  ) async {
    if (action == 'edit') {
      await _openCreateScreen(context, existing: item);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDelete(context);
      if (!ok) return;
      await store.deleteAnnouncement(item.id);
      if (!context.mounted) return;
      showDeletedSnackBar(context);
    }
  }

  Future<void> _onLongPress(BuildContext context, Announcement item) async {
    final action = await showEditDeleteMenu(context);
    if (action == null || !context.mounted) return;
    await _onMenuSelected(context, item, action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final announcements = store.announcementsFor(selectedClass);
        final isEmpty = announcements.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('$selectedClass · Зарлал'),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreateScreen(context),
            tooltip: 'Шинэ зарлал',
            child: const Icon(Icons.add),
          ),
          body: isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Text(
                      'Зарлал байхгүй байна',
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
                    ...announcements.map((item) {
                      final isUnread = store.isAnnouncementUnread(item.id);

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radius,
                          ),
                          onTap: () => _openDetail(context, item),
                          onLongPress: () => _onLongPress(context, item),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.card),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.campaign,
                                  color: AppColors.announcement,
                                ),
                                const SizedBox(width: AppSpacing.gap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item.isFeatured) ...[
                                        const Text('📌'),
                                        const SizedBox(
                                          height: AppSpacing.itemSm,
                                        ),
                                      ],
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (isUnread)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Шинэ',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.itemSm),
                                      Text(item.date),
                                      const SizedBox(height: AppSpacing.itemSm),
                                      Text(
                                        item.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Цэс',
                                  onSelected: (value) =>
                                      _onMenuSelected(context, item, value),
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('✏️ Засах'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('🗑 Устгах'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
