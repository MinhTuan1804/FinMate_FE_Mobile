import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/app_config/presentation/controllers/app_config_controller.dart';

String _featureLabel(String key) => switch (key) {
      'chatAi' => 'Trò chuyện AI',
      'voice' => 'Giọng nói',
      'billScan' => 'Quét hóa đơn',
      'notificationReading' => 'Đọc thông báo ngân hàng',
      'groups' => 'Tài chính nhóm',
      'support' => 'Hỗ trợ (ticket)',
      'marketAlerts' => 'Cảnh báo giá tăng',
      'community' => 'Cộng đồng',
      'subscriptions' => 'Gói đăng ký',
      _ => key,
    };

/// Màn test `GET /api/v1/app-config` — public, không cần đăng nhập.
class AppConfigScreen extends ConsumerWidget {
  const AppConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình app'),
        actions: [
          IconButton(
            key: const ValueKey('app-config-refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(appConfigProvider),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (config) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Phiên bản cấu hình: ${config.version}', key: const ValueKey('app-config-version')),
            Text('Giờ máy chủ: ${config.serverTime}'),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Bảo trì',
              children: [
                SwitchListTile(
                  key: const ValueKey('app-config-maintenance-enabled'),
                  title: const Text('Đang bảo trì'),
                  value: config.maintenance.enabled,
                  onChanged: null,
                ),
                if (config.maintenance.enabled) ...[
                  Text(config.maintenance.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(config.maintenance.message),
                  if (config.maintenance.estimatedEndAt != null)
                    Text('Dự kiến xong: ${config.maintenance.estimatedEndAt}'),
                ],
              ],
            ),
            _Section(
              title: 'Phiên bản app',
              children: [
                Text('Tối thiểu: ${config.appVersion.minVersion}'),
                Text('Mới nhất: ${config.appVersion.latestVersion}'),
                Text('Buộc cập nhật: ${config.appVersion.forceUpdate}'),
                if (config.appVersion.storeUrl.isNotEmpty) Text('Store: ${config.appVersion.storeUrl}'),
              ],
            ),
            _Section(
              title: 'Công tắc tính năng',
              children: [
                for (final entry in {
                  'chatAi': config.features.chatAi,
                  'voice': config.features.voice,
                  'billScan': config.features.billScan,
                  'notificationReading': config.features.notificationReading,
                  'groups': config.features.groups,
                  'support': config.features.support,
                  'marketAlerts': config.features.marketAlerts,
                  'community': config.features.community,
                  'subscriptions': config.features.subscriptions,
                }.entries)
                  SwitchListTile(
                    key: ValueKey('app-config-feature-${entry.key}'),
                    title: Text(_featureLabel(entry.key)),
                    value: entry.value,
                    onChanged: null,
                  ),
              ],
            ),
            _Section(
              title: 'Giao diện',
              children: [
                if (config.theme.primaryColor != null) Text('Màu chính: ${config.theme.primaryColor}'),
                if (config.theme.backgroundColor != null) Text('Màu nền: ${config.theme.backgroundColor}'),
                if (config.theme.fontFamily != null) Text('Font: ${config.theme.fontFamily}'),
                Text('Hệ số cỡ chữ: ${config.theme.textScale}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
