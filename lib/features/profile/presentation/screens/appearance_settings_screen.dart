import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn H3: Giao diện & Hiển thị (theo Figma). Chỉ có hai cài đặt thật là chế độ màu và giảm hiệu ứng trong suốt, áp dụng ngay.
/// Cỡ chữ áp dụng thật toàn app. Ẩn số dư, giảm chuyển động và tăng tương phản chưa có cơ chế nên hiện khóa kèm nhãn "Sắp có".
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final reduceTransparency = ref.watch(reduceTransparencyProvider);
    final textScale = ref.watch(textScaleProvider);

    void select(ThemeMode mode) =>
        ref.read(themeModeProvider.notifier).state = mode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao diện & Hiển thị'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(
            icon: LucideIcons.arrowLeft,
            size: 40,
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: AmbientGlassBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'CHẾ ĐỘ HIỂN THỊ',
                style: AppTypography.sectionLabel(context),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ThemeCard(
                    key: const ValueKey('theme-light'),
                    title: 'Sáng',
                    subtitle: 'Mặc định',
                    mode: ThemeMode.light,
                    selected: currentTheme == ThemeMode.light,
                    onSelect: () => select(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ThemeCard(
                    key: const ValueKey('theme-dark'),
                    title: 'Tối',
                    subtitle: 'Dịu mắt ban đêm',
                    mode: ThemeMode.dark,
                    selected: currentTheme == ThemeMode.dark,
                    onSelect: () => select(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ThemeCard(
                    key: const ValueKey('theme-system'),
                    title: 'Hệ thống',
                    subtitle: 'Tự động',
                    mode: ThemeMode.system,
                    selected: currentTheme == ThemeMode.system,
                    onSelect: () => select(ThemeMode.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'TÙY CHỌN HIỂN THỊ',
                style: AppTypography.sectionLabel(context),
              ),
            ),
            LiquidGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _lockedTile(
                    context,
                    LucideIcons.eyeOff,
                    'Ẩn số dư trên màn hình chính',
                    'Chống nhìn trộm nơi công cộng',
                  ),
                  const Divider(height: 1),
                  _lockedTile(
                    context,
                    LucideIcons.ban,
                    'Giảm hiệu ứng chuyển động',
                    'Hạn chế hoạt ảnh khi chuyển màn',
                  ),
                  const Divider(height: 1),
                  _lockedTile(
                    context,
                    LucideIcons.contrast,
                    'Tăng độ tương phản (High Contrast)',
                    'Chữ và viền đậm hơn',
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    key: const ValueKey('reduce-transparency'),
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.layers,
                        size: 18,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    title: Text(
                      'Giảm hiệu ứng trong suốt',
                      style: AppTypography.body(
                        context,
                      ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Chuyển nền kính mờ sang màu đặc để tăng độ tương phản và tiết kiệm pin.',
                      style: AppTypography.caption(
                        context,
                      ).copyWith(fontSize: 12),
                    ),
                    value: reduceTransparency,
                    onChanged: (val) =>
                        ref.read(reduceTransparencyProvider.notifier).state =
                            val,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'CỠ CHỮ HIỂN THỊ',
                      style: AppTypography.sectionLabel(context),
                    ),
                  ),
                  Text(
                    _scaleLabel(textScale),
                    style: AppTypography.caption(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            LiquidGlassCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Slider(
                    key: const ValueKey('text-scale'),
                    value: _scaleStops
                        .indexOf(textScale)
                        .clamp(0, 2)
                        .toDouble(),
                    min: 0,
                    max: 2,
                    divisions: 2,
                    label: _scaleLabel(textScale),
                    onChanged: (v) =>
                        ref.read(textScaleProvider.notifier).state =
                            _scaleStops[v.round()],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nhỏ', style: AppTypography.caption(context)),
                      Text(
                        'Chuẩn',
                        style: AppTypography.caption(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text('Lớn', style: AppTypography.caption(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inset(context, 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BẢN XEM TRƯỚC TRỰC TIẾP',
                          style: AppTypography.caption(
                            context,
                          ).copyWith(fontSize: 10.5, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FinMate hiển thị số tiền rõ ràng: ${formatVnd(BigInt.from(120000))}',
                          style: AppTypography.body(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _scaleStops = [0.9, 1.0, 1.15];

String _scaleLabel(double scale) => switch (scale) {
  0.9 => 'Nhỏ',
  1.15 => 'Lớn',
  _ => 'Chuẩn (Mặc định)',
};

/// Công tắc theo Figma nhưng app chưa có cơ chế tương ứng: hiện khóa kèm nhãn "Sắp có", không giả vờ hoạt động.
Widget _lockedTile(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
) {
  return SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    secondary: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: AppColors.textSecondary(context)),
    ),
    title: Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: AppTypography.body(
              context,
            ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.2),
            borderRadius: AppSpacing.roundedPill,
          ),
          child: Text(
            'Sắp có',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.slateOn(context),
            ),
          ),
        ),
      ],
    ),
    subtitle: Text(
      subtitle,
      style: AppTypography.caption(context).copyWith(fontSize: 12),
    ),
    value: false,
    onChanged: null,
  );
}

/// Thẻ chọn chế độ màu: hình xem trước thu nhỏ của giao diện, nhãn và dấu chọn; có nhãn cho trình đọc màn hình.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primaryAction(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Giao diện $title, $subtitle',
      child: GestureDetector(
        onTap: onSelect,
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(height: 112, child: _Preview(mode: mode)),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          LucideIcons.check,
                          size: 12,
                          color: AppColors.onPrimaryAction(context),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.body(context).copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hình xem trước thu nhỏ của một giao diện: nền, thanh tiêu đề, thẻ và nút giả bằng các khối màu.
class _Preview extends StatelessWidget {
  const _Preview({required this.mode});

  final ThemeMode mode;

  static const _lightBg = Color(0xFFE8EFF8);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightBar = Color(0xFFB8C7DA);
  static const _darkBg = Color(0xFF0F172A);
  static const _darkCard = Color(0xFF1E293B);
  static const _darkBar = Color(0xFF475569);

  Widget _mock({
    required Color bg,
    required Color card,
    required Color bar,
    required Color accent,
  }) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 5,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: bar.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const Spacer(),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = _mock(
      bg: _lightBg,
      card: _lightCard,
      bar: _lightBar,
      accent: const Color(0xFFA3D0FF),
    );
    final dark = _mock(
      bg: _darkBg,
      card: _darkCard,
      bar: _darkBar,
      accent: const Color(0xFF7CA9D6),
    );
    return switch (mode) {
      ThemeMode.light => light,
      ThemeMode.dark => dark,
      ThemeMode.system => Row(
        children: [
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: SizedBox(width: 200, child: light),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 0.5,
                child: SizedBox(width: 200, child: dark),
              ),
            ),
          ),
        ],
      ),
    };
  }
}
