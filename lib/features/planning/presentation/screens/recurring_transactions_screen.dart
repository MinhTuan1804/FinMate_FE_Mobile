import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Quy đổi một khoản chi định kỳ về đồng/tháng (số nguyên, làm tròn xuống). Tuần = 52/12 tháng.
BigInt monthlyEquivalent(RecurringItemEntity item) => switch (item.cadence) {
      RecurringCadence.weekly => item.amountCents * BigInt.from(52) ~/ BigInt.from(12),
      RecurringCadence.monthly => item.amountCents,
      RecurringCadence.yearly => item.amountCents ~/ BigInt.from(12),
    };

/// Số ngày còn lại đến hạn theo lịch (âm = đã quá hạn), bỏ qua giờ phút.
int daysUntilDue(DateTime due, DateTime now) =>
    DateTime.utc(due.year, due.month, due.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

/// Hạn trong vòng 7 ngày tới (kể cả đã quá hạn chưa xử lý), chỉ tính khoản chi đang hoạt động.
const _soonDays = 7;

bool _isDueSoon(RecurringItemEntity i, DateTime now) =>
    i.status == RecurringStatus.active && i.direction == RecurringDirection.outflow && daysUntilDue(i.nextDueDate, now) <= _soonDays;

enum _Filter { all, soon, paused, suggested }

String _perCadence(RecurringCadence c) => switch (c) {
      RecurringCadence.weekly => '/ tuần',
      RecurringCadence.monthly => '/ tháng',
      RecurringCadence.yearly => '/ năm',
    };

/// Màn G7: Chi phí định kỳ, dữ liệu thật từ `/api/v1/recurring-items`.
/// Figma có thêm "Đã thanh toán"/"Đánh dấu đã trả"/"Tự động trừ qua ví" nhưng BE chưa có lịch sử thanh toán nên không hiển thị.
class RecurringTransactionsScreen extends ConsumerStatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  ConsumerState<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends ConsumerState<RecurringTransactionsScreen> {
  _Filter _filter = _Filter.all;

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _cancel(RecurringItemEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hủy khoản định kỳ'),
        content: Text('Hủy "${item.name}"? Hệ thống sẽ không tự đề xuất lại cho cùng người nhận này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text('Hủy khoản', style: TextStyle(color: GlassColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(recurringItemsControllerProvider.notifier).cancel(item.id), 'Đã hủy khoản định kỳ.');
  }

  void _openForm([RecurringItemEntity? item]) => context.push('/planning/recurring/form', extra: item);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recurringItemsControllerProvider);
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(context, title: 'Chi phí định kỳ'),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(recurringItemsControllerProvider.notifier).load(),
                  child: state.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _Message(
                      text: errorMessage(e),
                      actionLabel: 'Thử lại',
                      onAction: () => ref.read(recurringItemsControllerProvider.notifier).load(),
                    ),
                    data: _content,
                  ),
                ),
              ),
              GlassBottomDock(
                actions: [
                  GlassPrimaryButton(
                    key: const ValueKey('recurring-add'),
                    label: 'Thêm khoản định kỳ mới',
                    icon: LucideIcons.circlePlus,
                    onPressed: _openForm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<RecurringItemEntity> all) {
    final items = all.where((i) => i.status != RecurringStatus.rejected && i.status != RecurringStatus.cancelled).toList();
    if (items.isEmpty) {
      return const _Message(
        text: 'Chưa có khoản định kỳ nào. Bấm "Thêm khoản định kỳ mới" để tạo tiền nhà, thuê bao hay lương hằng tháng.',
      );
    }
    final now = DateTime.now();
    final active = items.where((i) => i.status == RecurringStatus.active && i.direction == RecurringDirection.outflow).toList();
    final totalMonthly = active.fold(BigInt.zero, (sum, i) => sum + monthlyEquivalent(i));
    final soon = items.where((i) => _isDueSoon(i, now)).toList();
    final soonTotal = soon.fold(BigInt.zero, (sum, i) => sum + i.amountCents);

    bool matches(RecurringItemEntity i) => switch (_filter) {
          _Filter.all => true,
          _Filter.soon => _isDueSoon(i, now),
          _Filter.paused => i.status == RecurringStatus.paused,
          _Filter.suggested => i.status == RecurringStatus.suggested,
        };
    final counts = {
      _Filter.all: items.length,
      _Filter.soon: soon.length,
      _Filter.paused: items.where((i) => i.status == RecurringStatus.paused).length,
      _Filter.suggested: items.where((i) => i.status == RecurringStatus.suggested).length,
    };
    const labels = {
      _Filter.all: 'Tất cả',
      _Filter.soon: 'Sắp đến hạn',
      _Filter.paused: 'Tạm dừng',
      _Filter.suggested: 'Đề xuất',
    };
    final shown = items.where(matches).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _summary(active.length, totalMonthly, soon.length, soonTotal),
        const SizedBox(height: 16),
        // Một hàng cuộn ngang, không xuống dòng.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filter.values) ...[
                GlassFilterChip(
                  key: ValueKey('recurring-filter-${f.name}'),
                  label: labels[f]!,
                  count: counts[f]!,
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
                if (f != _Filter.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Không có khoản nào trong nhóm này.', textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
          )
        else
          for (final item in shown) Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(item, now)),
      ],
    );
  }

  Widget _summary(int activeCount, BigInt totalMonthly, int soonCount, BigInt soonTotal) {
    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('TỔNG CHI PHÍ ĐỊNH KỲ THÁNG', style: GlassTypography.labelCaps(color: GlassColors.textSecondary))),
              const SizedBox(width: 8),
              Flexible(child: GlassBadge(text: '$activeCount khoản hoạt động')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                formatVnd(totalMonthly),
                key: const ValueKey('recurring-total'),
                style: GlassTypography.displayHero().copyWith(fontSize: 26),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ tháng', style: GlassTypography.bodyMd(color: GlassColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GlassColors.fieldFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GlassColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: GlassColors.warning, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Sắp đến hạn (7 ngày)', style: GlassTypography.bodySm(color: GlassColors.textSecondary))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(formatVnd(soonTotal), style: GlassTypography.labelNumeric().copyWith(fontSize: 15, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', FontWeight.w700.value.toDouble())])),
                const SizedBox(height: 2),
                Text(
                  soonCount == 0 ? 'Chưa có khoản nào' : '$soonCount khoản cần chú ý',
                  style: GlassTypography.bodySm(color: soonCount == 0 ? GlassColors.textMuted : GlassColors.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(RecurringItemEntity item, DateTime now) {
    final controller = ref.read(recurringItemsControllerProvider.notifier);
    final inflow = item.direction == RecurringDirection.inflow;
    final color = inflow ? GlassColors.success : GlassColors.slateAnchor;
    final suggested = item.status == RecurringStatus.suggested;
    final paused = item.status == RecurringStatus.paused;
    final days = daysUntilDue(item.nextDueDate, now);
    final due = DateFormat('dd/MM/yyyy').format(item.nextDueDate);

    final Widget badge;
    if (suggested) {
      badge = GlassBadge(text: item.status.label, color: GlassColors.warning, background: GlassColors.warning.withValues(alpha: 0.14));
    } else if (paused) {
      badge = GlassBadge(text: item.status.label, color: GlassColors.textSecondary, background: GlassColors.secondarySurface);
    } else if (!inflow && days < 0) {
      badge = GlassBadge(text: 'Quá hạn ${-days} ngày', color: GlassColors.danger, background: GlassColors.danger.withValues(alpha: 0.14));
    } else if (!inflow && days <= _soonDays) {
      badge = GlassBadge(
        text: days == 0 ? 'Sắp đến hạn (hôm nay)' : 'Sắp đến hạn (còn $days ngày)',
        color: GlassColors.warning,
        background: GlassColors.warning.withValues(alpha: 0.14),
      );
    } else {
      badge = GlassBadge(text: item.status.label, color: GlassColors.success, background: GlassColors.success.withValues(alpha: 0.14));
    }

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: ValueKey('recurring-${item.id}'),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Sửa ${item.name}',
                child: InkWell(
                  borderRadius: GlassRadius.roundedInput,
                  onTap: () => _openForm(item),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GlassColors.fieldBorder),
                        ),
                        child: Icon(inflow ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text('Hạn: $due · ${item.cadence.label}', style: GlassTypography.bodySm()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.formattedAmount,
                            style: GlassTypography.labelNumeric(color: inflow ? GlassColors.success : GlassColors.textPrimary)
                                .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(_perCadence(item.cadence), style: GlassTypography.bodySm()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 24, color: GlassColors.glassBorder),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  badge,
                  if (suggested)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AsyncActionBuilder(
                          onPressed: () => _run(() => controller.reject(item.id), 'Đã từ chối.'),
                          builder: (_, onTap, running) => TextButton(
                            key: ValueKey('reject-${item.id}'),
                            onPressed: onTap,
                            child: running ? const ButtonLoadingIndicator() : Text('Từ chối', style: TextStyle(color: GlassColors.danger)),
                          ),
                        ),
                        AsyncActionBuilder(
                          onPressed: () => _run(() => controller.confirm(item.id), 'Đã xác nhận.'),
                          builder: (_, onTap, running) => TextButton(
                            key: ValueKey('confirm-${item.id}'),
                            onPressed: onTap,
                            child: running ? const ButtonLoadingIndicator() : const Text('Xác nhận'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          key: ValueKey(paused ? 'resume-${item.id}' : 'pause-${item.id}'),
                          onPressed: () => paused
                              ? _run(() => controller.resume(item.id), 'Đã tiếp tục.')
                              : _run(() => controller.pause(item.id), 'Đã tạm dừng.'),
                          child: Text(paused ? 'Tiếp tục' : 'Tạm dừng'),
                        ),
                        IconButton(
                          key: ValueKey('cancel-${item.id}'),
                          tooltip: 'Hủy khoản định kỳ',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(LucideIcons.trash2, size: 18, color: GlassColors.danger),
                          onPressed: () => _cancel(item),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Cuộn được để kéo-làm-mới hoạt động cả khi rỗng/lỗi.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Text(text, textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          Center(child: GlassSecondaryButton(label: actionLabel!, onPressed: onAction)),
        ],
      ],
    );
  }
}
