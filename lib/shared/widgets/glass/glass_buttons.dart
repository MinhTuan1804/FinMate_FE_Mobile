import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Nút pill chính: nền mực đậm, dùng cho hành động chính của màn (DESIGN.md, mục Buttons).
class GlassPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassColors.ink,
          disabledBackgroundColor: GlassColors.ink.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
                  Text(label, style: GlassTypography.buttonText()),
                ],
              ),
      ),
    );
  }
}

/// Nút pill phụ: nền xanh nhạt, dùng cho hành động thứ hai (vd. "Tạo tài khoản mới").
class GlassSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GlassSecondaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassColors.secondarySurface,
          foregroundColor: GlassColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: GlassRadius.roundedPill,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Text(label, style: GlassTypography.buttonText(color: GlassColors.ink)),
      ),
    );
  }
}

/// Nút viền kính trong suốt — hành động nhẹ nhất (vd. "Từ chối và thoát").
class GlassGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GlassGhostButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: GlassColors.slateAnchor,
          side: BorderSide(color: GlassColors.accentSkyBlue.withValues(alpha: 0.4)),
          shape: const RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Text(label, style: GlassTypography.buttonText(color: GlassColors.slateAnchor)),
      ),
    );
  }
}
