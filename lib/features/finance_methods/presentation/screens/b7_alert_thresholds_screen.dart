import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

/// Nền cho hộp lồng bên trong thẻ kính: trắng mờ ở giao diện sáng, trắng rất nhạt ở giao diện tối (trắng 60% trên nền tối thành xám đục).
Color _insetFill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.6);

/// H4 / B7 — Ngưỡng cảnh báo chi tiêu (theo Figma). Hai mức T1 (nhắc sớm) và T2 (báo động) chỉnh bằng thanh trượt, lưu hoặc xóa về mặc định;
/// ví dụ bằng tiền tính từ ngân sách tổng của người dùng (không có ngân sách thì ẩn). Phần "Phương thức gửi" là tùy chọn thông báo thật của hồ sơ.
/// Báo cáo cuối ngày, cảnh báo giao dịch lớn và âm thanh trong Figma chưa có ở BE nên không hiển thị.
class AlertThresholdsScreen extends ConsumerStatefulWidget {
  const AlertThresholdsScreen({super.key});

  @override
  ConsumerState<AlertThresholdsScreen> createState() => _AlertThresholdsScreenState();
}

class _AlertThresholdsScreenState extends ConsumerState<AlertThresholdsScreen> {
  int? _t1;
  int? _t2;
  bool _savingPrefs = false;

  void _syncFrom(AlertThresholdSettingsEntity t) {
    _t1 ??= t.t1Pct;
    _t2 ??= t.t2Pct;
  }

  Future<void> _save() async {
    if (_t1 == null || _t2 == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alertThresholdsControllerProvider.notifier).setPersonal(t1Pct: _t1!, t2Pct: _t2!);
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu ngưỡng cảnh báo.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alertThresholdsControllerProvider.notifier).clearPersonal();
      setState(() {
        _t1 = null;
        _t2 = null;
      });
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _setPrefs(NotificationPrefs next) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingPrefs = true);
    try {
      await ref.read(authControllerProvider.notifier).updateNotificationPrefs(next);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  static String _sourceLabel(AlertThresholdSettingsEntity t) => switch (t.source) {
        'personal' => 'cá nhân',
        'method' => t.methodName == null ? 'theo cách quản lý' : 'theo cách ${t.methodName}',
        _ => 'mặc định hệ thống',
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(alertThresholdsControllerProvider);
    final prefs = ref.watch(authControllerProvider).valueOrNull?.notificationPrefs;
    final limit = ref.watch(planningControllerProvider).valueOrNull?.overallBudget?.limitAmountCents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngưỡng cảnh báo chi tiêu'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [TextButton(onPressed: _clear, child: const Text('Mặc định'))],
      ),
      body: AmbientGlassBackground(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage(e), style: AppTypography.body(context), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => ref.read(alertThresholdsControllerProvider.notifier).load(), child: const Text('Thử lại')),
                ],
              ),
            ),
          ),
          data: (t) {
            _syncFrom(t);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _intro(context),
                      const SizedBox(height: 16),
                      _levels(context, t, limit),
                      if (prefs != null) ...[
                        const SizedBox(height: 16),
                        _delivery(context, prefs),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: LiquidGlassPillButton(
                      key: const ValueKey('threshold-save'),
                      label: 'Lưu cài đặt cảnh báo',
                      icon: LucideIcons.circleCheck,
                      isFullWidth: true,
                      onPressed: _save,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return LiquidGlassCard(
      variant: LiquidGlassVariant.iridescentHero,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.22), shape: BoxShape.circle),
            child: Icon(LucideIcons.slidersHorizontal, size: 20, color: AppColors.slateOn(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HỖ TRỢ THÔNG MINH', style: AppTypography.sectionLabel(context)),
                const SizedBox(height: 4),
                Text(
                  'Nhận nhắc nhẹ ở mức 1 và cảnh báo mạnh ở mức 2 khi chi tiêu chạm các mốc này để tránh vượt ngân sách.',
                  style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levels(BuildContext context, AlertThresholdSettingsEntity t, BigInt? limit) {
    final t1 = _t1 ?? t.t1Pct;
    final t2 = _t2 ?? t.t2Pct;
    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mức cảnh báo', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Kéo để chỉnh điểm chạm', style: AppTypography.caption(context)),
                  ],
                ),
              ),
              if (limit != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.18), borderRadius: AppSpacing.roundedPill),
                    child: Text(
                      'Hạn mức ${formatVnd(limit)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateOn(context)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Đang áp dụng: $t1% · $t2% (${_sourceLabel(t)})',
            key: const ValueKey('threshold-effective'),
            style: AppTypography.caption(context).copyWith(fontSize: 12.5),
          ),
          Text(
            'Mặc định hệ thống: ${t.systemDefault.t1Pct}% · ${t.systemDefault.t2Pct}%',
            style: AppTypography.caption(context).copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _legendDot(AppColors.safe, '0%'),
              _legendDot(AppColors.warning, '$t1%'),
              _legendDot(AppColors.danger, '100%'),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: AppSpacing.roundedPill,
              gradient: const LinearGradient(colors: [AppColors.safe, AppColors.warning, AppColors.danger]),
            ),
          ),
          const SizedBox(height: 16),
          _level(
            context,
            icon: LucideIcons.bellRing,
            color: AppColors.warning,
            title: 'Mức 1: Cảnh báo sớm',
            sliderKey: 'threshold-t1-input',
            value: t1,
            min: 1,
            max: 98,
            onChanged: (v) => setState(() => _t1 = v),
            exampleLabel: 'Ví dụ thực tế',
            limit: limit,
          ),
          const SizedBox(height: 12),
          _level(
            context,
            icon: LucideIcons.triangleAlert,
            color: AppColors.danger,
            title: 'Mức 2: Báo động khẩn',
            sliderKey: 'threshold-t2-input',
            value: t2,
            min: 2,
            max: 99,
            onChanged: (v) => setState(() => _t2 = v),
            exampleLabel: 'Mức chạm ngưỡng',
            limit: limit,
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _level(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String sliderKey,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required String exampleLabel,
    required BigInt? limit,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _insetFill(context), borderRadius: AppSpacing.roundedLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$value%', style: AppTypography.tabular(TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color))),
                  Text('ngân sách', style: AppTypography.caption(context).copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.18),
              thumbColor: AppColors.textPrimary(context),
              overlayColor: color.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 6,
            ),
            child: Slider(
              key: ValueKey(sliderKey),
              value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value%',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          if (limit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: _insetFill(context), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: Text('$exampleLabel:', style: AppTypography.caption(context).copyWith(fontSize: 12))),
                  Flexible(
                    child: Text(
                      '${formatVnd(limit * BigInt.from(value) ~/ BigInt.from(100))} / ${formatVnd(limit)}',
                      textAlign: TextAlign.right,
                      style: AppTypography.tabular(AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _delivery(BuildContext context, NotificationPrefs prefs) {
    Widget toggle({
      required String key,
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required NotificationPrefs Function(bool) next,
    }) {
      return SwitchListTile.adaptive(
        key: ValueKey(key),
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: AppColors.textSecondary(context)),
        ),
        title: Text(title, style: AppTypography.body(context).copyWith(fontSize: 14.5, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: AppTypography.caption(context).copyWith(fontSize: 12)),
        value: value,
        onChanged: _savingPrefs ? null : (v) => _setPrefs(next(v)),
      );
    }

    return LiquidGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phương thức & Thời điểm gửi', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
          const Divider(height: 20),
          toggle(
            key: 'pref-push',
            icon: LucideIcons.messageSquareDot,
            title: 'Thông báo đẩy tức thì',
            subtitle: 'Nhận thông báo ngay trên điện thoại',
            value: prefs.pushEnabled,
            next: (v) => NotificationPrefs(pushEnabled: v, budgetAlertsEnabled: prefs.budgetAlertsEnabled, missionRemindersEnabled: prefs.missionRemindersEnabled),
          ),
          toggle(
            key: 'pref-budget',
            icon: LucideIcons.bellRing,
            title: 'Cảnh báo ngân sách',
            subtitle: 'Nhắc khi chi tiêu chạm mức 1 và mức 2',
            value: prefs.budgetAlertsEnabled,
            next: (v) => NotificationPrefs(pushEnabled: prefs.pushEnabled, budgetAlertsEnabled: v, missionRemindersEnabled: prefs.missionRemindersEnabled),
          ),
          toggle(
            key: 'pref-mission',
            icon: LucideIcons.target,
            title: 'Nhắc nhở nhiệm vụ',
            subtitle: 'Nhắc các việc và mục tiêu đang theo dõi',
            value: prefs.missionRemindersEnabled,
            next: (v) => NotificationPrefs(pushEnabled: prefs.pushEnabled, budgetAlertsEnabled: prefs.budgetAlertsEnabled, missionRemindersEnabled: v),
          ),
        ],
      ),
    );
  }
}
