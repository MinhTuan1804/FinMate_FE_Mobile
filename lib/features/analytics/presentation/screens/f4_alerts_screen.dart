import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/alert_action_runner.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

enum _Tab { all, open, confirmed }

const _anomalyKindLabel = {
  'category_spike': 'Chi tiêu danh mục tăng đột biến',
  'merchant_spike': 'Chi tiêu tăng đột biến',
  'duplicate': 'Nghi trùng giao dịch',
};

const _alertKind = {
  'low_balance': ('Cảnh báo số dư thấp', LucideIcons.trendingDown),
  'budget_risk': ('Cảnh báo vượt ngân sách', LucideIcons.trendingUp),
  'bill_due': ('Hóa đơn sắp đến hạn', LucideIcons.receipt),
  'bill_status_check': ('Kiểm tra hóa đơn', LucideIcons.receipt),
  'income_late': ('Thu nhập đến trễ', LucideIcons.calendarClock),
  'price_change': ('Giá thay đổi', LucideIcons.tag),
  'anomaly': ('Chi tiêu bất thường', LucideIcons.triangleAlert),
  'group_budget': ('Ngân sách nhóm', LucideIcons.users),
  'group_goal': ('Mục tiêu nhóm', LucideIcons.target),
  'purchase_reminder': ('Nhắc ngày mua', LucideIcons.calendarClock),
  'weekly_digest': ('Tổng kết tuần', LucideIcons.calendarClock),
};

const _resolutionLabel = {
  'normal': 'Bình thường',
  'one_off': 'Một lần, không lặp lại',
  'wrong_entry': 'Ghi nhận sai',
  'suspicious': 'Đáng ngờ',
};

/// F4 — Cảnh báo & Bất thường (Luồng 6). Gộp 2 nguồn dữ liệu dự báo đã có sẵn
/// ([forecastAlertsControllerProvider], [anomaliesControllerProvider]) thành 1 danh sách — đúng 2
/// loại thẻ trong Stitch (thẻ cảnh báo ngân sách/dự báo và thẻ giao dịch bất thường).
///
/// Khác BE thật so với Stitch (áp dụng "Stitch vs BE thật"): nút "Hữu ích" không có feedback
/// tương ứng ở BE (chỉ nhận `feedback: "inaccurate"`) nên disable thay vì giả vờ hoạt động; nút
/// "Điều chỉnh hạn mức tuần này" trỏ tới 1 màn sửa ngân sách theo tuần chưa tồn tại (Luồng 5 ngân
/// sách theo danh mục chưa build) nên disable. Link cuối trang trỏ `/forecast-settings` (màn cài
/// đặt ngưỡng dự báo ĐÃ có thật) thay vì "H4" (Luồng 7/Cài đặt chưa build màn nào).
class F4AlertsScreen extends ConsumerStatefulWidget {
  const F4AlertsScreen({super.key});

  @override
  ConsumerState<F4AlertsScreen> createState() => _F4AlertsScreenState();
}

class _F4AlertsScreenState extends ConsumerState<F4AlertsScreen> {
  _Tab _tab = _Tab.all;

  /// Nút đã làm xong (khóa `alertId:chỉ số`) và nút đang chạy; chỉ sống trong phiên màn hình
  final Set<String> _done = {};
  String? _running;

  late final AlertActionRunner _runner = AlertActionRunner(
    raiseBudgetLimit: (categoryId, limit) =>
        ref.read(planningControllerProvider.notifier).createOrUpdateBudget(categoryId: categoryId, limitAmountCents: limit),
    resumeRecurring: (id) => ref.read(recurringItemsControllerProvider.notifier).resume(id),
  );

  /// Bấm nút hành động của cảnh báo: điều hướng thì đi luôn, còn lại gọi API có sẵn; lỗi thì báo lý do và cho bấm lại.
  Future<void> _runAction(ForecastAlertEntity alert, int index) async {
    final action = alert.actions[index];
    final key = '${alert.id}:$index';
    if (_running != null || _done.contains(key)) return;
    if (action.kind == ForecastAlertAction.openForecast) {
      context.push('/forecast');
      return;
    }
    setState(() => _running = key);
    try {
      final ran = await _runner.run(action);
      if (!mounted) return;
      setState(() {
        _running = null;
        if (ran) _done.add(key);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Widget _actionButtons(ForecastAlertEntity alert) {
    final runnable = [for (var i = 0; i < alert.actions.length; i++) if (alert.actions[i].canRun) i];
    if (alert.markedInaccurate || runnable.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in runnable)
            if (_done.contains('${alert.id}:$i'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(AlertActionRunner.doneLabel(alert.actions[i].kind), style: GlassTypography.bodySm(color: GlassColors.success)),
              )
            else
              AsyncActionBuilder(
                onPressed: _running != null ? null : () => _runAction(alert, i),
                builder: (_, onTap, running) => FilledButton.tonal(
                  key: ValueKey('alert-action-${alert.id}-$i'),
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: running ? const ButtonLoadingIndicator() : Text(_running == '${alert.id}:$i' ? 'Đang xử lý...' : alert.actions[i].title),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(forecastAlertsControllerProvider);
    final anomaliesAsync = ref.watch(anomaliesControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary), onPressed: () => context.pop()),
          title: Text('Cảnh báo & Bất thường', style: GlassTypography.headlineMd()),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Cài đặt ngưỡng cảnh báo',
              icon: Icon(LucideIcons.slidersHorizontal, color: GlassColors.textPrimary),
              onPressed: () => context.push('/finance-methods/alert-thresholds'),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(forecastAlertsControllerProvider.notifier).load();
              await ref.read(anomaliesControllerProvider.notifier).load();
            },
            child: alertsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errorCenter(e, () => ref.read(forecastAlertsControllerProvider.notifier).load()),
              data: (alerts) => anomaliesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _errorCenter(e, () => ref.read(anomaliesControllerProvider.notifier).load()),
                data: (anomalies) => _buildContent(alerts, anomalies),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCenter(Object error, VoidCallback retry) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage(error), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
              TextButton(onPressed: retry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );

  Widget _buildContent(List<ForecastAlertEntity> alerts, List<AnomalyEntity> anomalies) {
    final openAlerts = alerts.where((a) => !a.markedInaccurate).toList();
    final confirmedAnomalies = anomalies.where((a) => a.isResolved).toList();
    final openAnomalies = anomalies.where((a) => !a.isResolved).toList();

    final total = alerts.length + anomalies.length;
    final (visibleAlerts, visibleAnomalies) = switch (_tab) {
      _Tab.all => (alerts, anomalies),
      _Tab.open => (openAlerts, openAnomalies),
      _Tab.confirmed => (<ForecastAlertEntity>[], confirmedAnomalies),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _buildBanner(total),
        const SizedBox(height: 16),
        _buildTabs(total, openAlerts.length + openAnomalies.length, confirmedAnomalies.length),
        const SizedBox(height: 16),
        if (visibleAlerts.isEmpty && visibleAnomalies.isEmpty)
          GlassCard(child: Text('Không có mục nào ở bộ lọc này.', textAlign: TextAlign.center, style: GlassTypography.bodyMd()))
        else ...[
          for (final a in visibleAlerts) ...[_alertCard(a), const SizedBox(height: 14)],
          for (final a in visibleAnomalies) ...[_anomalyCard(a), const SizedBox(height: 14)],
        ],
        const SizedBox(height: 4),
        _buildFooterTip(),
      ],
    );
  }

  Widget _buildBanner(int total) {
    final monthLabel = DateFormat('MM', 'vi_VN').format(DateTime.now());
    return GlassCard(
      level: 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: GlassColors.warning, shape: BoxShape.circle),
            child: Icon(LucideIcons.triangleAlert, color: GlassColors.onInk, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GlassBadge(text: 'AI PHÁT HIỆN', color: GlassColors.warning),
                    Text('Tháng $monthLabel', style: GlassTypography.bodySm()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0 ? 'Không có điểm bất thường nào tháng này' : '$total điểm cần lưu ý trong tháng này',
                  style: GlassTypography.headlineSm(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(int all, int open, int confirmed) {
    Widget chip(String label, int count, _Tab tab) {
      final selected = _tab == tab;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? GlassColors.ink : GlassColors.glassFill,
              borderRadius: GlassRadius.roundedPill,
              border: Border.all(color: selected ? GlassColors.ink : GlassColors.glassBorder),
            ),
            child: Text(
              '$label ($count)',
              style: GlassTypography.bodyMd(color: selected ? GlassColors.onInk : GlassColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Tất cả', all, _Tab.all),
          chip('Chưa xử lý', open, _Tab.open),
          chip('Đã xác nhận', confirmed, _Tab.confirmed),
        ],
      ),
    );
  }

  /// Viền thẻ theo mức độ (Figma: viền vàng cho cảnh báo, viền xanh cho đã xác nhận).
  Widget _bordered(Color color, Widget card) => Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: GlassRadius.roundedCard,
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: card,
      );

  Widget _chip(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: GlassRadius.roundedPill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Flexible(child: Text(text, style: GlassTypography.labelCaps(color: color), overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  Widget _alertCard(ForecastAlertEntity alert) {
    final (kindLabel, kindIcon) = _alertKind[alert.kind] ?? ('Cảnh báo dự báo', LucideIcons.bell);
    final tone = alert.kind == 'low_balance' ? GlassColors.danger : GlassColors.warning;
    return _bordered(
      alert.markedInaccurate ? GlassColors.glassBorder : tone,
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chip(kindIcon, kindLabel, tone),
            const SizedBox(height: 8),
            Text(
              alert.markedInaccurate ? 'Đã phản hồi' : 'Chưa giải quyết',
              style: GlassTypography.bodySm(color: alert.markedInaccurate ? GlassColors.success : GlassColors.textMuted),
            ),
            const SizedBox(height: 10),
            Text(alert.title, style: GlassTypography.headlineSm()),
            const SizedBox(height: 6),
            Text(alert.body, style: GlassTypography.bodyMd()),
            const SizedBox(height: 12),
            _actionButtons(alert),
            // BE chỉ nhận phản hồi "inaccurate" nên không có nút "Hữu ích" (xem ghi chú đầu file).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text('Phản hồi độ chính xác:', style: GlassTypography.bodySm()),
                OutlinedButton(
                  onPressed: alert.markedInaccurate ? null : () => ref.read(forecastAlertsControllerProvider.notifier).markInaccurate(alert.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GlassColors.danger,
                    side: BorderSide(color: GlassColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text('Không chính xác', style: GlassTypography.bodySm(color: alert.markedInaccurate ? GlassColors.textMuted : GlassColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _anomalyCard(AnomalyEntity anomaly) {
    final title = _anomalyKindLabel[anomaly.kind] ?? 'Giao dịch bất thường';
    final dateText = anomaly.transactedAt == null ? '' : ' ngày ${DateFormat('dd/MM').format(anomaly.transactedAt!)}';
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final category = categories.where((c) => c.id == anomaly.categoryId).firstOrNull;
    final tone = anomaly.isResolved ? GlassColors.success : GlassColors.warning;
    final strong = GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700);

    return _bordered(
      tone,
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(LucideIcons.triangleAlert, title, tone),
                if (anomaly.merchantName != null) _chip(LucideIcons.store, anomaly.merchantName!, GlassColors.slateAnchor),
                if (anomaly.resolution == 'normal') _chip(LucideIcons.circleCheck, 'Đã xác nhận chính chủ', GlassColors.success),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: GlassTypography.bodyMd(),
                children: [
                  TextSpan(text: '-${anomaly.formattedAmount}', style: strong),
                  TextSpan(text: '$dateText (thường khoảng '),
                  TextSpan(text: anomaly.formattedTypical, style: strong),
                  const TextSpan(text: ').'),
                ],
              ),
            ),
            if (anomaly.merchantName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedInput),
                child: Row(
                  children: [
                    Icon(categoryIcon(category?.slug), size: 18, color: GlassColors.slateAnchor),
                    const SizedBox(width: 10),
                    Expanded(child: Text(anomaly.merchantName!, style: strong, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text('-${anomaly.formattedAmount}', style: GlassTypography.labelNumeric(color: GlassColors.danger)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (anomaly.isResolved)
              Text('Phản hồi: ${_resolutionLabel[anomaly.resolution] ?? anomaly.resolution}', style: GlassTypography.bodySm(color: GlassColors.success))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _resolutionLabel.entries)
                    OutlinedButton(
                      onPressed: () => ref.read(anomaliesControllerProvider.notifier).sendFeedback(anomaly.id, entry.key),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: GlassColors.glassBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(entry.value, style: GlassTypography.bodySm(color: GlassColors.textPrimary)),
                    ),
                ],
              ),
            if (category != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(LucideIcons.tag, size: 14, color: GlassColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: GlassTypography.bodySm(), children: [
                        const TextSpan(text: 'Đã phân loại vào: '),
                        TextSpan(text: category.name, style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                // Chưa có màn chi tiết 1 giao dịch riêng — trỏ vào Lịch sử giao dịch (D1).
                onPressed: () => context.push('/transactions'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('Xem chứng từ', style: GlassTypography.bodyMd(color: GlassColors.accentSkyBlue), maxLines: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterTip() {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.sparkles, size: 20, color: GlassColors.slateAnchor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn muốn nhận cảnh báo sớm hơn?', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: GlassTypography.bodySm(),
                    children: [
                      const TextSpan(text: 'Vào '),
                      TextSpan(
                        text: 'Cài đặt ngưỡng cảnh báo',
                        style: GlassTypography.bodySm(color: GlassColors.accentSkyBlue).copyWith(fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()..onTap = () => context.push('/finance-methods/alert-thresholds'),
                      ),
                      const TextSpan(text: ' để tùy chỉnh mức độ nhạy của cảnh báo theo nhu cầu thực tế của bạn.'),
                    ],
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
