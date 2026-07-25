import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/confirm_delete.dart';
import 'announcement_create_screen.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.markAnnouncementsViewed(widget.selectedClass);
    });
  }

  Future<void> _openCreateScreen({Announcement? existing}) async {
    await Navigator.push<Announcement>(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementCreateScreen(
          className: widget.selectedClass,
          store: widget.store,
          existing: existing,
        ),
      ),
    );
    if (!mounted) return;
  }

  Future<void> _onMenuSelected(Announcement item, String action) async {
    if (action == 'edit') {
      await _openCreateScreen(existing: item);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDelete(context);
      if (!ok) return;
      await widget.store.deleteAnnouncement(item.id);
      if (!mounted) return;
      showDeletedSnackBar(context);
    }
  }

  Future<void> _onLongPress(Announcement item) async {
    final action = await showEditDeleteMenu(context);
    if (action == null || !mounted) return;
    await _onMenuSelected(item, action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final announcements = widget.store.announcementsFor(
          widget.selectedClass,
        );
        final isEmpty = announcements.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.selectedClass} · Зарлал'),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreateScreen(),
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
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radius,
                          ),
                          onLongPress: () => _onLongPress(item),
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
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                      _onMenuSelected(item, value),
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
