import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Thanh điều hướng dưới: hai tab mỗi bên và nút QUÉT QR chuyển khoản ở GIỮA (ô vuông bo góc chứa icon quét mã).
///
/// Chỉ có bốn tab điều hướng vì năm mục cộng nút giữa sẽ chật trên màn hình nhỏ; "Phân tích" vào từ lối tắt trên màn Trang chủ. [currentIndex] là tab đang đứng (0 Trang chủ, 1 Sổ thu chi, 2 Kế hoạch,
/// 3 Cá nhân), -1 nếu không tab nào. Mỗi mục cao tối thiểu 56 để chạm được bằng ngón cái, có nhãn chữ (không chỉ icon) và nhãn trợ năng.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _centerSize = 56.0;

  static const _items = <_NavItem>[
    _NavItem(LucideIcons.house, 'Trang chủ', '/home'),
    _NavItem(LucideIcons.receipt, 'Sổ thu chi', '/transactions'),
    _NavItem(LucideIcons.target, 'Kế hoạch', '/planning'),
    _NavItem(LucideIcons.user, 'Cá nhân', '/profile'),
  ];

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    final path = _items[index].path;
    // Trang chủ là gốc của ngăn xếp; các tab còn lại mở chồng lên như trước đây.
    index == 0 ? context.go(path) : context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.bottomNavigationBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _tab(context, 0),
                _tab(context, 1),
                Expanded(child: Center(child: _CenterScanButton(onPressed: () => context.push('/qr-scan')))),
                _tab(context, 2),
                _tab(context, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final item = _items[index];
    final selected = index == currentIndex;
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _go(context, index),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.navLabel(selected: selected, color: color),
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

/// Ô vuông bo góc ở giữa thanh nav. Màu đảo theo theme (đen trên nền sáng, sáng trên nền tối) để luôn nổi hơn các tab xung quanh mà không cần thêm màu thương hiệu.
class _CenterScanButton extends StatelessWidget {
  const _CenterScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Quét mã QR chuyển khoản',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Quét mã QR chuyển khoản',
        child: Material(
          color: scheme.onSurface,
          borderRadius: AppSpacing.roundedLarge,
          child: InkWell(
            borderRadius: AppSpacing.roundedLarge,
            onTap: onPressed,
            child: SizedBox(
              width: AppBottomNav._centerSize,
              height: AppBottomNav._centerSize,
              child: Icon(LucideIcons.scanQrCode, size: 28, color: scheme.surface),
            ),
          ),
        ),
      ),
    );
  }
}
