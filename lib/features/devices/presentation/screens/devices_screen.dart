import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/devices/data/devices_repository.dart';

const _platforms = [('Android', 'Android'), ('Ios', 'iOS'), ('Web', 'Web')];

String _randomToken() {
  final random = Random();
  final chars = List.generate(24, (_) => random.nextInt(36)).map((n) => n.toRadixString(36)).join();
  return 'test-device-token-$chars';
}

/// Màn test đăng ký/gỡ token FCM (không có Firebase thật trong app — nhập/sinh token giả để test
/// đúng hợp đồng API) và đăng xuất toàn bộ thiết bị.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _tokenController = TextEditingController(text: _randomToken());
  String _platform = 'Android';
  bool _registering = false;
  bool _unregistering = false;
  bool _loggingOutAll = false;
  String? _lastResult;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _registering = true);
    try {
      await ref.read(devicesRepositoryProvider).registerDevice(token: token, platform: _platform);
      if (mounted) setState(() => _lastResult = 'Đã đăng ký thiết bị ($_platform).');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _unregister() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _unregistering = true);
    try {
      await ref.read(devicesRepositoryProvider).unregisterDevice(token);
      if (mounted) setState(() => _lastResult = 'Đã gỡ đăng ký thiết bị.');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _unregistering = false);
    }
  }

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
      appBar: AppBar(title: const Text('Thiết bị & thông báo push')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Token thiết bị (test)', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const ValueKey('device-token'),
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'Token FCM',
                      suffixIcon: IconButton(
                        key: const ValueKey('device-token-regenerate'),
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () => setState(() => _tokenController.text = _randomToken()),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('device-platform'),
                    initialValue: _platform,
                    decoration: const InputDecoration(labelText: 'Nền tảng'),
                    items: [for (final p in _platforms) DropdownMenuItem(value: p.$1, child: Text(p.$2))],
                    onChanged: (v) => setState(() => _platform = v ?? _platform),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          key: const ValueKey('device-register'),
                          onPressed: _registering ? null : _register,
                          child: const Text('Đăng ký'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('device-unregister'),
                          onPressed: _unregistering ? null : _unregister,
                          child: const Text('Gỡ đăng ký'),
                        ),
                      ),
                    ],
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_lastResult!, style: AppTypography.caption(context)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phiên đăng nhập', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Thu hồi refresh token của mọi thiết bị, kể cả thiết bị này — bạn sẽ bị đăng xuất ngay.',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    key: const ValueKey('device-logout-all'),
                    onPressed: _loggingOutAll ? null : _logoutAllDevices,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                    child: const Text('Đăng xuất tất cả thiết bị', style: TextStyle(color: AppColors.danger)),
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
