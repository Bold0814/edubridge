import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin_permission_gate.dart';
import 'test_data_reset_screen.dart';

/// Admin-only data & security hub.
class DataSecurityScreen extends StatelessWidget {
  const DataSecurityScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminPermissionGate(
      store: store,
      child: Scaffold(
        appBar: AppBar(title: const Text('Өгөгдөл ба аюулгүй байдал')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              'Аюултай үйлдэл',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.itemSm),
            Text(
              'Эдгээр үйлдэл нь мэдээллийг бүрмөсөн устгана. Буцаах боломжгүй.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sectionSm),
            Card(
              color: const Color(0xFFFFF5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.cleaning_services_outlined,
                      color: AppColors.error,
                    ),
                    title: const Text('Туршилтын өгөгдөл цэвэрлэх'),
                    subtitle: const Text(
                      'Сургууль болон админ бүртгэлийг хадгална',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TestDataResetScreen(store: store),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.error,
                    ),
                    title: const Text('Сургууль болон бүх өгөгдлийг устгах'),
                    subtitle: const Text(
                      'Онлайн хамгаалалт бүрэн тохирсны дараа',
                    ),
                    trailing: const Icon(Icons.lock_outline),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Боломжгүй'),
                          content: const Text(
                            'Энэ үйлдэл онлайн хамгаалалт бүрэн тохирсны дараа идэвхжинэ.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Хаах'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
