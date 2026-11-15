import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/subscriptions/domain/subscriptions.dart';
import 'package:finmate/features/subscriptions/presentation/controllers/subscriptions_controller.dart';

/// Màn H14 & H15: Gói đăng ký và lịch sử thanh toán. Việc mua diễn ra trên web (app chỉ xin liên kết rồi mở trình duyệt).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  Future<void> _openCheckout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final link = await ref.read(webSessionActionProvider)();
      final uri = Uri.tryParse(link.url);
      if (uri == null || uri.scheme != 'https') {
        messenger.showSnackBar(const SnackBar(content: Text('Liên kết thanh toán không hợp lệ.')));
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Không mở được trình duyệt.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(mySubscriptionProvider);
    ref.invalidate(subscriptionPlansProvider);
    ref.invalidate(subscriptionOrdersProvider);
    try {
      await ref.read(mySubscriptionProvider.future);
    } catch (_) {
      // Lỗi đã hiện ở thẻ gói hiện tại kèm nút Thử lại
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói dịch vụ FinMate'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              const _CurrentPlanCard(),
              const SizedBox(height: 24),
              const _CycleToggle(),
              const SizedBox(height: 16),
              const _PlansList(),
              const SizedBox(height: 20),
              LiquidGlassPillButton(
                label: 'Mua hoặc gia hạn gói trên web',
                icon: LucideIcons.externalLink,
                isFullWidth: true,
                onPressed: () => _openCheckout(context, ref),
              ),
              const SizedBox(height: 28),
              Text('LỊCH SỬ THANH TOÁN', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),
              const _OrdersList(),
              const SizedBox(height: 20),
              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.slateOn(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Không lưu mật khẩu ngân hàng của bạn', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
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
}

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Chu kỳ giá đang xem (true = theo năm). Chỉ đổi cách hiển thị giá trên thẻ gói, không ảnh hưởng đơn mua (mua trên web).
final _yearlyProvider = StateProvider.autoDispose<bool>((ref) => true);

/// Phần trăm tiết kiệm khi mua theo năm so với 12 tháng, tính từ giá thật của gói trả phí đầu tiên có đủ hai giá; null nếu không tính được.
int? _yearlySavingPercent(List<SubscriptionPlanEntity> plans) {
  for (final p in plans) {
    final m = p.monthlyPriceCents;
    final y = p.yearlyPriceCents;
    if (!p.isFree && m != null && y != null && m > BigInt.zero) {
      final full = m * BigInt.from(12);
      if (y >= full) return null;
      return ((full - y) * BigInt.from(100) ~/ full).toInt();
    }
  }
  return null;
}

class _CycleToggle extends ConsumerWidget {
  const _CycleToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearly = ref.watch(_yearlyProvider);
    final saving = _yearlySavingPercent(ref.watch(subscriptionPlansProvider).valueOrNull ?? const []);
    Widget tab(String label, bool value, {String? badge}) {
      final selected = yearly == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            key: ValueKey('cycle-${value ? 'year' : 'month'}'),
            onTap: () => ref.read(_yearlyProvider.notifier).state = value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: selected ? AppColors.primaryAction(context) : Colors.transparent, borderRadius: AppSpacing.roundedPill),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? AppColors.onPrimaryAction(context) : AppColors.textPrimary(context)),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFFFD9E4), borderRadius: AppSpacing.roundedPill),
                      child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF31101E))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.inset(context, 0.55), borderRadius: AppSpacing.roundedPill),
      child: Row(children: [tab('Theo năm', true, badge: saving == null ? null : '-$saving%'), tab('Theo tháng', false)]),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      variant: LiquidGlassVariant.subtle,
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.danger.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(errorMessage(error), style: AppTypography.caption(context))),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends ConsumerWidget {
  const _CurrentPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySubscriptionProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _ErrorRetry(error: e, onRetry: () => ref.invalidate(mySubscriptionProvider)),
      data: (mine) => LiquidGlassCard(
        variant: LiquidGlassVariant.iridescentHero,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: AppSpacing.roundedPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.sparkles, size: 12, color: AppColors.slateOn(context)),
                  const SizedBox(width: 4),
                  Text(
                    mine.planName.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slateOn(context), letterSpacing: 0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(mine.isFree ? 'Bạn đang dùng gói miễn phí' : 'Bạn đang dùng gói ${mine.planName}', style: AppTypography.h1(context).copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              mine.expiresAt != null
                  ? 'Hết hạn ngày ${_dateFmt.format(mine.expiresAt!)}'
                  : (mine.isFree ? 'Không giới hạn thời gian' : 'Chưa có ngày hết hạn'),
              style: AppTypography.caption(context).copyWith(fontSize: 13),
            ),
            if (mine.upcoming.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final p in mine.upcoming)
                Text(
                  'Sắp tới: ${p.planName}, ${_dateFmt.format(p.startsAt)} đến ${_dateFmt.format(p.endsAt)}',
                  style: AppTypography.caption(context).copyWith(fontSize: 12),
                ),
            ],
            if (mine.features.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Đã dùng tháng này', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 8),
              for (final f in mine.features) _UsageRow(usage: f),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.usage});

  final FeatureUsageEntity usage;

  @override
  Widget build(BuildContext context) {
    final limit = usage.monthlyLimit;
    final text = !usage.enabled ? 'Chưa mở' : (limit == null ? '${usage.used} (không giới hạn)' : '${usage.used}/$limit');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(usage.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(text, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _PlansList extends ConsumerWidget {
  const _PlansList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionPlansProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _ErrorRetry(error: e, onRetry: () => ref.invalidate(subscriptionPlansProvider)),
      data: (plans) {
        if (plans.isEmpty) return Text('Chưa có gói nào đang bán.', style: AppTypography.caption(context));
        final yearly = ref.watch(_yearlyProvider);
        return Column(
          children: [
            for (final p in plans) ...[
              _PlanCard(plan: p, yearly: yearly),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.yearly});

  final SubscriptionPlanEntity plan;
  final bool yearly;

  @override
  Widget build(BuildContext context) {
    // Theo chu kỳ đang chọn; gói chỉ có một loại giá thì hiện loại đó.
    final cycleYearly = yearly ? plan.yearlyPriceCents != null || plan.monthlyPriceCents == null : plan.monthlyPriceCents == null;
    final amount = cycleYearly ? plan.yearlyPriceCents : plan.monthlyPriceCents;
    final unit = cycleYearly ? '/ năm' : '/ tháng';
    return LiquidGlassCard(
      variant: plan.isFree ? LiquidGlassVariant.standard : LiquidGlassVariant.iridescentHero,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: AppTypography.h2(context).copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(plan.description!, style: AppTypography.caption(context).copyWith(fontSize: 12)),
          ],
          const SizedBox(height: 12),
          if (plan.isFree)
            Text('Miễn phí', style: AppTypography.displayBalance(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800))
          else if (amount == null)
            Text('Chưa có giá', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: Text(formatVnd(amount), style: AppTypography.displayBalance(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800))),
                const SizedBox(width: 6),
                Text(unit, style: AppTypography.caption(context)),
              ],
            ),
          const Divider(height: 24),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(f.enabled ? LucideIcons.check : LucideIcons.x, size: 16, color: f.enabled ? AppColors.safe : AppColors.textMutedDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.monthlyLimit != null ? '${f.name} (${f.monthlyLimit} lần/tháng)' : f.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _cycleLabel(String c) => switch (c) {
      'Monthly' => 'Theo tháng',
      'Yearly' => 'Theo năm',
      _ => c,
    };

String _statusLabel(String s) => switch (s) {
      'Pending' => 'Chờ thanh toán',
      'Paid' => 'Đã thanh toán',
      'Cancelled' => 'Đã hủy',
      'Expired' => 'Hết hạn',
      'Voided' => 'Đã hoàn tác',
      'NeedsReview' => 'Cần kiểm tra lại',
      _ => s,
    };

Color _statusColor(String s) => switch (s) {
      'Paid' => AppColors.safe,
      'Pending' => AppColors.warning,
      'NeedsReview' => AppColors.danger,
      _ => AppColors.textMutedDark,
    };

class _OrdersList extends ConsumerWidget {
  const _OrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionOrdersProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _ErrorRetry(error: e, onRetry: () => ref.invalidate(subscriptionOrdersProvider)),
      data: (orders) {
        if (orders.isEmpty) {
          return LiquidGlassCard(
            variant: LiquidGlassVariant.subtle,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(LucideIcons.history, size: 20, color: AppColors.slateOn(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Bạn chưa có đơn mua gói nào.', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final o in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.subtle,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${o.planName} • ${_cycleLabel(o.cycle)}', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${o.invoiceNumber} • ${_dateFmt.format(o.createdAt.toLocal())}', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatVnd(o.amountCents), style: AppTypography.tabular(AppTypography.body(context).copyWith(fontWeight: FontWeight.w700))),
                          const SizedBox(height: 2),
                          Text(_statusLabel(o.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(o.status))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
