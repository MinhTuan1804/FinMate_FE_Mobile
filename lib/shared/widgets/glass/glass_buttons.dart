import 'dart:async';

import 'package:flutter/material.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Nút pill chính: nền mực đậm, dùng cho hành động chính của màn (DESIGN.md, mục Buttons).
class GlassPrimaryButton extends StatelessWidget {
  final String label;

  /// Trả về Future → nút tự hiện spinner và khoá tới khi xong.
  final FutureOr<void> Function()? onPressed;
  final bool loading;
  final IconData? icon;

  const GlassPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return AsyncActionBuilder(
      onPressed: onPressed,
      loading: loading,
      builder: (context, onPressed, loading) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlassColors.ink,
            disabledBackgroundColor: GlassColors.ink.withValues(alpha: 0.5),
            foregroundColor: GlassColors.onInk,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: loading
              ? _ButtonSpinner(color: GlassColors.onInk)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: GlassColors.onInk), const SizedBox(width: 8)],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, style: GlassTypography.buttonText(), maxLines: 1),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Nút pill phụ: nền xanh nhạt, dùng cho hành động thứ hai (vd. "Tạo tài khoản mới").
class GlassSecondaryButton extends StatelessWidget {
  final String label;

  /// Trả về Future → nút tự hiện spinner và khoá tới khi xong.
  final FutureOr<void> Function()? onPressed;

  final bool loading;

  const GlassSecondaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return AsyncActionBuilder(
      onPressed: onPressed,
      loading: loading,
      builder: (context, onPressed, loading) => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlassColors.secondarySurface,
            foregroundColor: GlassColors.ink,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: GlassRadius.roundedPill,
              side: BorderSide(color: GlassColors.fieldBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // FittedBox: nút nửa hàng hẹp thì chữ co lại thay vì xuống dòng
          child: loading
              ? _ButtonSpinner(color: GlassColors.ink)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1, style: GlassTypography.buttonText(color: GlassColors.ink)),
                ),
        ),
      ),
    );
  }
}

/// Nút viền kính trong suốt — hành động nhẹ nhất (vd. "Từ chối và thoát").
class GlassGhostButton extends StatelessWidget {
  final String label;

  /// Trả về Future → nút tự hiện spinner và khoá tới khi xong.
  final FutureOr<void> Function()? onPressed;

  final bool loading;

  const GlassGhostButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return AsyncActionBuilder(
      onPressed: onPressed,
      loading: loading,
      builder: (context, onPressed, loading) => SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: GlassColors.slateAnchor,
            side: BorderSide(color: GlassColors.accentSkyBlue.withValues(alpha: 0.4)),
            shape: const RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: loading
              ? _ButtonSpinner(color: GlassColors.slateAnchor)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1, style: GlassTypography.buttonText(color: GlassColors.slateAnchor)),
                ),
        ),
      ),
    );
  }
}

/// Spinner trong nút: cùng kích thước với dòng chữ để nút không nhảy chiều cao khi đổi trạng thái.
class _ButtonSpinner extends StatelessWidget {
  final Color color;
  const _ButtonSpinner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang xử lý',
      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
    );
  }
}
