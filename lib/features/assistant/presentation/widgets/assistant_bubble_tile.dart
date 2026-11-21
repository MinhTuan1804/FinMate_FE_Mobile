import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/assistant/data/assistant_bubble_bridge.dart';

/// Máy có hỗ trợ bong bóng FinMate AI không (Android 11+). Màn Cá nhân chỉ hiện công tắc khi true.
final assistantBubbleSupportedProvider = FutureProvider.autoDispose<bool>(
  (ref) async => (await ref.watch(assistantBubbleBridgeProvider).status()).supported,
);

/// Công tắc "Bong bóng trợ lý". Chế độ system: xin quyền thông báo, bong bóng đang tắt thì mở cài đặt bong bóng.
/// Chế độ overlay: chưa có quyền "Hiện trên các ứng dụng khác" thì mở màn cấp quyền. Cả hai hoàn tất khi người
/// dùng quay lại app. Trạng thái công tắc đọc thẳng từ Android, nên kéo bong bóng vào X cũng tự tắt công tắc.
class AssistantBubbleTile extends ConsumerStatefulWidget {
  const AssistantBubbleTile({super.key});

  @override
  ConsumerState<AssistantBubbleTile> createState() => _AssistantBubbleTileState();
}

class _AssistantBubbleTileState extends ConsumerState<AssistantBubbleTile> with WidgetsBindingObserver {
  AssistantBubbleStatus? _status;
  bool _busy = false;

  /// Đã đưa người dùng sang cài đặt bong bóng của Android, chờ họ quay lại để hiện bong bóng.
  bool _waitingForSettings = false;

  AssistantBubbleBridge get _bridge => ref.read(assistantBubbleBridgeProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }

  Future<void> _onResumed() async {
    if (_waitingForSettings) {
      _waitingForSettings = false;
      final s = await _bridge.status();
      final ready = s.mode == AssistantBubbleMode.overlay ? s.overlayPermission : s.bubblesAllowed;
      if (ready) {
        await _bridge.show();
      } else {
        _snack(s.mode == AssistantBubbleMode.overlay
            ? 'FinMate chưa được phép hiện trên các ứng dụng khác.'
            : 'Bong bóng của FinMate vẫn đang tắt trong cài đặt Android.');
      }
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final s = await _bridge.status();
    if (mounted) setState(() => _status = s);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(bool enable) async {
    setState(() => _busy = true);
    try {
      if (enable) {
        await _enable();
      } else {
        await _bridge.hide();
      }
    } on PlatformException {
      _snack('Không đổi được bong bóng trợ lý. Vui lòng thử lại.');
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() async {
    final status = await _bridge.status();
    if (status.mode == AssistantBubbleMode.overlay) {
      if (!status.overlayPermission) {
        _waitingForSettings = true;
        _snack('Bật "Hiện trên các ứng dụng khác" cho FinMate rồi quay lại app để hoàn tất.');
        await _bridge.openOverlaySettings();
        return;
      }
      if (!await _bridge.show()) _snack('Không hiện được bong bóng. Kiểm tra quyền hiển thị của FinMate.');
      return;
    }
    if (!status.notificationPermission && !await _bridge.requestNotificationPermission()) {
      _snack('Cần cho phép FinMate gửi thông báo để hiện bong bóng.');
      return;
    }
    if (!(await _bridge.status()).bubblesAllowed) {
      _waitingForSettings = true;
      _snack('Bật "Bong bóng" cho FinMate rồi quay lại app để hoàn tất.');
      await _bridge.openBubbleSettings();
      return;
    }
    if (!await _bridge.show()) _snack('Không hiện được bong bóng. Kiểm tra quyền thông báo của FinMate.');
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final on = status?.showing ?? false;
    final subtitle = switch (status) {
      null => 'Đang kiểm tra…',
      _ when on => 'Đang hiện. Kéo bong bóng vào dấu X để ẩn.',
      _ => 'Mở FinMate AI nhanh từ bất kỳ ứng dụng nào.',
    };
    final disabled = status == null || _busy;

    return MergeSemantics(
      child: InkWell(
        key: const ValueKey('assistant-bubble-tile'),
        onTap: disabled ? null : () => _toggle(!on),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(LucideIcons.messageCircle, size: 20, color: AppColors.textSecondary(context)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bong bóng trợ lý',
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTypography.caption(context).copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                key: const ValueKey('assistant-bubble-switch'),
                value: on,
                onChanged: disabled ? null : _toggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
