import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/config/app_version.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Chặn toàn app bằng một popup khi hệ thống đang bảo trì hoặc app quá cũ. Bảo trì được ưu tiên hơn cập nhật.
/// Bản đang chặn thì phần app bên dưới không nhận chạm, không vào cây trợ năng và nút Back không thoát được khỏi popup.
class AppConfigGate extends ConsumerStatefulWidget {
  const AppConfigGate({super.key, required this.child, this.currentVersion = kAppVersion});

  final Widget child;

  /// Phiên bản app đang chạy; tách ra để test giả lập app cũ.
  final String currentVersion;

  @override
  ConsumerState<AppConfigGate> createState() => _AppConfigGateState();
}

class _AppConfigGateState extends ConsumerState<AppConfigGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Người dùng quay lại app sau một lúc (có thể đã bảo trì xong hoặc vừa bắt đầu): hỏi ngay thay vì chờ vòng định kỳ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(ref.read(appConfigProvider.notifier).refresh());
  }

  bool _mustUpdate(AppVersionConfig version) =>
      isOlderVersion(widget.currentVersion, version.minVersion) ||
      (version.forceUpdate && isOlderVersion(widget.currentVersion, version.latestVersion));

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final Widget? blocker = config.maintenance.enabled
        ? MaintenanceNotice(config: config.maintenance, onRetry: ref.read(appConfigProvider.notifier).refresh)
        : _mustUpdate(config.appVersion)
            ? UpdateNotice(config: config.appVersion, currentVersion: widget.currentVersion)
            : null;

    return PopScope(
      canPop: blocker == null,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: blocker != null,
              child: ExcludeSemantics(excluding: blocker != null, child: widget.child),
            ),
          ),
          if (blocker != null) Positioned.fill(child: blocker),
        ],
      ),
    );
  }
}

/// Khung chung của hai popup: nền mờ che app, thẻ ở giữa cuộn được (chữ phóng to hay màn hình nhỏ vẫn không tràn).
class _NoticeFrame extends StatelessWidget {
  const _NoticeFrame({required this.icon, required this.title, required this.message, required this.children});

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: AppColors.backgroundDark.withValues(alpha: 0.88),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: AppSpacing.roundedLarge,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.15), borderRadius: AppSpacing.roundedMedium),
                          child: ExcludeSemantics(child: Icon(icon, size: 28, color: theme.colorScheme.primary)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(title, textAlign: TextAlign.center, style: AppTypography.h2(context)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(context).copyWith(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, height: 1.4),
                      ),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup bảo trì: tiêu đề và lời nhắn do admin viết, giờ dự kiến xong (nếu có) và nút Thử lại có trạng thái đang kiểm tra.
class MaintenanceNotice extends StatefulWidget {
  const MaintenanceNotice({super.key, required this.config, required this.onRetry});

  final MaintenanceConfig config;
  final Future<void> Function() onRetry;

  @override
  State<MaintenanceNotice> createState() => _MaintenanceNoticeState();
}

class _MaintenanceNoticeState extends State<MaintenanceNotice> {
  bool _busy = false;
  bool _checked = false;  // đã thử lại ít nhất một lần mà vẫn đang bảo trì

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      // Hết bảo trì thì cả popup bị gỡ, widget này không còn mounted.
      if (mounted) {
        setState(() {
          _busy = false;
          _checked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = widget.config.estimatedEndAt?.toLocal();
    final secondary = Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return _NoticeFrame(
      icon: LucideIcons.wrench,
      title: widget.config.title,
      message: widget.config.message,
      children: [
        if (end != null && end.isAfter(DateTime.now())) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(child: Icon(LucideIcons.clock, size: 16, color: secondary)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text('Dự kiến xong lúc ${DateFormat('HH:mm dd/MM/yyyy').format(end)}', style: AppTypography.body(context).copyWith(color: secondary))),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : _retry,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _busy
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: AppSpacing.sm),
                    Text('Đang kiểm tra...'),
                  ],
                )
              : const Text('Thử lại'),
        ),
        if (_checked && !_busy) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text('Hệ thống vẫn đang bảo trì. Vui lòng thử lại sau.', textAlign: TextAlign.center, style: AppTypography.body(context).copyWith(color: secondary)),
          ),
        ],
      ],
    );
  }
}

/// Màn buộc cập nhật. Dự án chưa có `url_launcher` (và không được thêm dependency khi chưa hỏi) nên liên kết cửa hàng hiện dưới dạng chữ chọn được kèm nút sao chép.
class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key, required this.config, required this.currentVersion});

  final AppVersionConfig config;
  final String currentVersion;

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  Timer? _resetCopied;
  bool _copied = false;

  @override
  void dispose() {
    _resetCopied?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.config.storeUrl));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetCopied?.cancel();
    _resetCopied = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.config.storeUrl;
    final secondary = Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return _NoticeFrame(
      icon: LucideIcons.download,
      title: 'Cần cập nhật FinMate',
      message: 'Phiên bản ${widget.currentVersion} không còn được hỗ trợ. Vui lòng cập nhật lên phiên bản ${widget.config.latestVersion} để tiếp tục.',
      children: [
        const SizedBox(height: AppSpacing.xl),
        if (url.isEmpty)
          Text('Hãy mở cửa hàng ứng dụng trên máy và cập nhật FinMate.', textAlign: TextAlign.center, style: AppTypography.body(context).copyWith(color: secondary))
        else ...[
          SelectableText(url, textAlign: TextAlign.center, style: AppTypography.body(context)),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: OutlinedButton.icon(
              onPressed: _copy,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: Icon(_copied ? LucideIcons.check : LucideIcons.copy, size: 18),
              label: Text(_copied ? 'Đã sao chép' : 'Sao chép liên kết'),
            ),
          ),
        ],
      ],
    );
  }
}
