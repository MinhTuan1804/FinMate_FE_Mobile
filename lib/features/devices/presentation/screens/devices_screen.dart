import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Phiên đăng nhập: đăng xuất toàn bộ thiết bị. Token thông báo đẩy do app tự đăng ký (push_messaging.dart), không có thao tác nào ở đây.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _loggingOutAll = false;

  Future<void> _logoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất tất cả thiết bị?'),
        content: const Text('Mọi thiết bị đang đăng nhập (kể cả thiết bị này) sẽ bị đăng xuất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất tất cả')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOutAll = true);
    try {
      await ref.read(authControllerProvider.notifier).logoutAllDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loggingOutAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phiên đăng nhập')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thiết bị đang đăng nhập', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Thu hồi phiên đăng nhập của mọi thiết bị, kể cả thiết bị này — bạn sẽ bị đăng xuất ngay.',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AsyncActionBuilder(
                    onPressed: _loggingOutAll ? null : _logoutAllDevices,
                    builder: (_, onTap, running) => OutlinedButton(
                      key: const ValueKey('device-logout-all'),
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                      child: running ? const ButtonLoadingIndicator() : const Text('Đăng xuất tất cả thiết bị', style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
