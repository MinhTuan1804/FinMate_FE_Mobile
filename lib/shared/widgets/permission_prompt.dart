import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/permissions/permission_service.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';

/// Hộp thoại "hãy bật quyền này nếu muốn dùng chức năng": giải thích vì sao cần, nút "Mở Cài đặt" đưa thẳng tới trang cài đặt của app.
/// Dùng khi quyền đã bị từ chối hẳn và việc đang làm dở (ghi âm, chụp hóa đơn…) không tiếp tục được.
Future<void> showPermissionSettingsDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
}) async {
  final open = await GlassDialog.confirm(
    context,
    title: title,
    message: message,
    confirmLabel: 'Mở Cài đặt',
    cancelLabel: 'Để sau',
  );
  if (open == true) await ref.read(permissionServiceProvider).openSettings();
}

/// Khối nằm ngay trong màn hình khi chức năng chính của màn không chạy được nếu thiếu quyền (vd màn quét QR cần camera).
/// [state] = denied: nút "Cho phép" hiện hộp xin quyền của hệ thống. blocked: hệ thống sẽ không hỏi nữa, nút "Mở Cài đặt".
class PermissionPrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final PermissionState state;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  /// Màn có nền tối (màn quét) thì chữ sáng.
  final bool dark;

  const PermissionPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.state,
    required this.onRequest,
    required this.onOpenSettings,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = state == PermissionState.blocked;
    final fg = dark ? Colors.white : GlassColors.textPrimary;
    final muted = dark ? Colors.white70 : GlassColors.textMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: fg),
            const SizedBox(height: 16),
            Text(title, style: GlassTypography.headlineSm(color: fg), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: GlassTypography.bodyMd(color: muted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: ValueKey(blocked ? 'permission-open-settings' : 'permission-request'),
                onPressed: blocked ? onOpenSettings : onRequest,
                icon: Icon(blocked ? LucideIcons.settings : LucideIcons.shieldCheck, size: 18),
                label: Text(blocked ? 'Mở Cài đặt' : 'Cho phép'),
                style: FilledButton.styleFrom(
                  backgroundColor: dark ? Colors.white : GlassColors.ink,
                  foregroundColor: dark ? Colors.black : GlassColors.onInk,
                ),
              ),
            ),
            if (blocked) ...[
              const SizedBox(height: 8),
              Text('Vào Quyền > bật quyền này, rồi quay lại FinMate.', style: GlassTypography.bodySm(color: muted), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
