import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Thanh điều hướng dưới phong cách Liquid Glass (Zenvest & Serene Glass FinTech):
/// Hai tab mỗi bên và nút QUÉT QR chuyển khoản ở GIỮA.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _centerSize = 52.0;

  static const _items = <_NavItem>[
    _NavItem(LucideIcons.house, 'Trang chủ', '/home'),
    _NavItem(LucideIcons.receipt, 'Giao dịch', '/transactions'),
    _NavItem(LucideIcons.target, 'Kế hoạch', '/planning'),
    _NavItem(LucideIcons.chartPie, 'Phân tích', '/analytics'),
  ];

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    context.go(_items[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = LiquidGlassTheme.of(context);
    final navBg = theme.bottomNavigationBarTheme.backgroundColor;
    final fill = glass.reduceTransparency
        ? (navBg ?? glass.solidElevatedFallbackFill)
        : glass.glassElevatedFill;

    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.vertical(top: AppSpacing.rXl),
        border: Border(
          top: BorderSide(color: glass.glassBorder, width: 1.0),
        ),
        boxShadow: glass.floatingShadows,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _tab(context, 0),
              _tab(context, 1),
              Expanded(
                child: Center(
                  child: _CenterScanButton(
                    onPressed: () => context.push('/qr-scan'),
                  ),
                ),
              ),
              _tab(context, 2),
              _tab(context, 3),
            ],
          ),
        ),
      ),
    );

    if (!glass.reduceTransparency) {
      bar = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: AppSpacing.rXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppSpacing.blurFloating,
            sigmaY: AppSpacing.blurFloating,
          ),
          child: bar,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: bar,
    );
  }

  Widget _tab(BuildContext context, int index) {
    final item = _items[index];
    final selected = index == currentIndex;
    final activeBg = AppColors.primaryAction(context);
    final activeIconFg = AppColors.onPrimaryAction(context);
    final activeTextColor = AppColors.textPrimary(context);
    final inactiveColor = AppColors.textMuted(context);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: AppSpacing.roundedMedium,
          onTap: () => _go(context, index),
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppSpacing.motionFast,
                  curve: AppSpacing.smoothCurve,
                  width: selected ? 34 : 30,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: selected ? activeIconFg : inactiveColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.navLabel(
                    selected: selected,
                    color: selected ? activeTextColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.path);

  final IconData icon;
  final String label;
  final String path;
}

/// Nút Quét QR ở chính giữa thanh điều hướng: nổi bật kiểu Serene Glass FinTech (#111827 trên nền sáng, #7CA9D6 trên nền tối).
class _CenterScanButton extends StatelessWidget {
  const _CenterScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.primaryAction(context);
    final fgColor = AppColors.onPrimaryAction(context);

    return Semantics(
      button: true,
      label: 'Quét mã QR chuyển khoản',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Quét mã QR chuyển khoản',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.roundedLarge,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: bgColor.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: bgColor,
            borderRadius: AppSpacing.roundedLarge,
            child: InkWell(
              borderRadius: AppSpacing.roundedLarge,
              onTap: onPressed,
              child: SizedBox(
                width: AppBottomNav._centerSize,
                height: AppBottomNav._centerSize,
                child: Icon(LucideIcons.scanQrCode, size: 26, color: fgColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
