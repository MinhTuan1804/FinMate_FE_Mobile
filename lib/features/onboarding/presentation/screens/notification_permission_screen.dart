import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Cuối chuỗi onboarding bắt buộc (sau [InitialSetupScreen], trước /survey) — hỏi chủ động quyền
/// đọc thông báo một lần duy nhất (§16.4). Không có trong Stitch gốc, tự thiết kế theo phong cách
/// Glass đã dùng cho [AiConsentScreen]. Quyền hệ thống Android không thể ép buộc nên luôn có nút
/// "Bỏ qua" — `notification_access_card.dart` ở màn Giao dịch vẫn là nơi bật lại sau này.
class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({super.key});

  Future<void> _enable(BuildContext context) async {
    await sharedNotificationBridge.openNotificationAccessSettings();
    // Mở màn cài đặt hệ thống không trả kết quả đồng bộ (OS permission) — đi tiếp luồng ngay,
    // trạng thái thật được đọc lại ở Transactions screen (NotificationAccessCard) sau đó.
    if (context.mounted) context.go('/survey');
  }

  void _skip(BuildContext context) => context.go('/survey');

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tự động ghi nhận giao dịch', style: GlassTypography.headlineLg()),
                const SizedBox(height: 8),
                Text(
                  'FinMate cần quyền đọc thông báo để tự động phát hiện giao dịch ngân hàng, '
                  'không cần bạn nhập tay.',
                  style: GlassTypography.bodyMd(),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.bellRing, color: GlassColors.slateAnchor, size: 20),
                          const SizedBox(width: 10),
                          Text('Vì sao cần quyền này?', style: GlassTypography.headlineSm()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'FinMate chỉ đọc thông báo biến động số dư từ ngân hàng/ví điện tử bạn chọn theo dõi, '
                        'không đọc nội dung tin nhắn hay thông báo khác.',
                        style: GlassTypography.bodyMd(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                GlassPrimaryButton(
                  key: const ValueKey('notif-permission-enable'),
                  label: 'Cấp quyền truy cập thông báo',
                  onPressed: () => _enable(context),
                ),
                const SizedBox(height: 12),
                GlassGhostButton(
                  key: const ValueKey('notif-permission-skip'),
                  label: 'Bỏ qua (có thể bật sau trong Cá nhân)',
                  onPressed: () => _skip(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
