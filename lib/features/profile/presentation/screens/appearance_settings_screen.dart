import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn H3: Tùy chỉnh Giao diện & Hiển thị (Appearance Settings Screen)
class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends ConsumerState<AppearanceSettingsScreen> {
  bool _hideBalanceDefault = false;

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeModeProvider);
    final reduceTransparency = ref.watch(reduceTransparencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao diện & Hiển thị'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CHẾ ĐỘ MÀU SẮC', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              // 3 Preview Cards: Sáng / Tối / Hệ thống
              Row(
                children: [
                  Expanded(
                    child: _themeCard(
                      context,
                      title: 'Sáng',
                      subtitle: 'Serene Sky',
                      mode: ThemeMode.light,
                      current: currentTheme,
                      bgColor: const Color(0xFFE8EFF8),
                      accentColor: AppColors.primary,
                      onSelect: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _themeCard(
                      context,
                      title: 'Tối',
                      subtitle: 'Obsidian',
                      mode: ThemeMode.dark,
                      current: currentTheme,
                      bgColor: const Color(0xFF0F172A),
                      accentColor: const Color(0xFF7CA9D6),
                      onSelect: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _themeCard(
                      context,
                      title: 'Hệ thống',
                      subtitle: 'Tự động',
                      mode: ThemeMode.system,
                      current: currentTheme,
                      bgColor: const Color(0xFF7CA9D6).withValues(alpha: 0.3),
                      accentColor: AppColors.primaryAction(context),
                      onSelect: () => ref.read(themeModeProvider.notifier).state = ThemeMode.system,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text('HIỆU ỨNG THỊ GIÁC & QUYỀN RIÊNG TƯ', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Giảm hiệu ứng trong suốt (Reduce Transparency)',
                        style: AppTypography.body(context).copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Chuyển nền kính mờ sang màu đặc để tăng độ tương phản và tiết kiệm pin.',
                        style: AppTypography.caption(context).copyWith(fontSize: 12),
                      ),
                      value: reduceTransparency,
                      onChanged: (val) {
                        ref.read(reduceTransparencyProvider.notifier).state = val;
                      },
                    ),
                    const Divider(height: 24),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Ẩn số dư tài sản mặc định',
                        style: AppTypography.body(context).copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Hiển thị số tiền dưới dạng •••••••• khi mở app ở nơi công cộng.',
                        style: AppTypography.caption(context).copyWith(fontSize: 12),
                      ),
                      value: _hideBalanceDefault,
                      onChanged: (val) => setState(() => _hideBalanceDefault = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text('ĐẶC TẢ THIẾT KẾ SERENE LIQUID GLASS', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảo vệ mắt & Chuẩn tương phản WCAG AA',
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nền trời sương xanh nhạt không chói, chữ số đậm rõ nét, không dùng gradient quá bão hòa.',
                      style: AppTypography.caption(context).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ThemeMode mode,
    required ThemeMode current,
    required Color bgColor,
    required Color accentColor,
    required VoidCallback onSelect,
  }) {
    final isSelected = mode == current;

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppSpacing.roundedLarge,
          border: Border.all(
            color: isSelected ? accentColor : AppColors.borderLight,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: isSelected
                  ? Icon(LucideIcons.circleCheck, color: accentColor, size: 18)
                  : const SizedBox(height: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: mode == ThemeMode.dark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: mode == ThemeMode.dark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
