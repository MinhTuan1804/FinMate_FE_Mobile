import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';

final _timeFormat = DateFormat('HH:mm - dd/MM');

String _kindTitle(AnomalyEntity a) {
  final merchant = a.merchantName;
  return switch (a.kind) {
    'category_spike' => 'Chi tiêu danh mục cao bất thường',
    'merchant_spike' => merchant == null ? 'Chi tiêu cao bất thường' : 'Chi tiêu tại $merchant cao bất thường',
    'duplicate' => 'Giao dịch có thể bị ghi trùng',
    _ => a.kind,
  };
}

String _resolutionLabel(String value) => switch (value) {
      'normal' => 'Bình thường',
      'one_off' => 'Chi một lần',
      'wrong_entry' => 'Nhập sai',
      'suspicious' => 'Giao dịch lạ',
      _ => value,
    };

/// Màn F4: Cảnh báo dự báo và khoản chi bất thường, dữ liệu thật từ `/api/v1/forecast/*`.
class SpendingAnomaliesScreen extends ConsumerWidget {
  const SpendingAnomaliesScreen({super.key});

  Future<void> _anomalyFeedback(BuildContext context, WidgetRef ref, String id, String resolution) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(anomaliesControllerProvider.notifier).sendFeedback(id, resolution);
      if (result.guidance != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Giao dịch lạ'),
            content: Text(result.guidance!),
            actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Đã hiểu'))],
          ),
        );
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Đã ghi nhận phản hồi của bạn.')));
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Future<void> _alertFeedback(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(forecastAlertsControllerProvider.notifier).markInaccurate(id);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomalies = ref.watch(anomaliesControllerProvider);
    final alerts = ref.watch(forecastAlertsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo & Bất thường'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(anomaliesControllerProvider.notifier).load(),
              ref.read(forecastAlertsControllerProvider.notifier).load(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              _summary(context, anomalies),
              const SizedBox(height: 20),
              Text('KHOẢN CHI BẤT THƯỜNG', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),
              _section<AnomalyEntity>(
                context: context,
                async: anomalies,
                emptyText: 'Không có khoản chi bất thường nào cần xem.',
                onRetry: () => ref.invalidate(anomaliesControllerProvider),
                builder: (a) => _anomalyCard(context, ref, a),
              ),
              const SizedBox(height: 20),
              Text('CẢNH BÁO DỰ BÁO', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),
              _section<ForecastAlertEntity>(
                context: context,
                async: alerts,
                emptyText: 'Chưa có cảnh báo dự báo nào.',
                onRetry: () => ref.invalidate(forecastAlertsControllerProvider),
                builder: (a) => _alertCard(context, ref, a),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, AsyncValue<List<AnomalyEntity>> anomalies) {
    final open = anomalies.valueOrNull?.where((a) => !a.isResolved).length;
    final title = open == null
        ? 'Đang kiểm tra chi tiêu'
        : open == 0
            ? 'Không có bất thường nào'
            : 'Phát hiện $open bất thường';
    return ZenvestHeroDeck(
      peekBadgeText: 'ANOMALY',
      child: LiquidGlassCard(
        variant: LiquidGlassVariant.iridescentHero,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.triangleAlert, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.h2(context).copyWith(fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    'Hệ thống đối chiếu lịch sử để bảo vệ ngân sách của bạn kịp thời.',
                    style: AppTypography.caption(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section<T>({
    required BuildContext context,
    required AsyncValue<List<T>> async,
    required String emptyText,
    required VoidCallback onRetry,
    required Widget Function(T) builder,
  }) {
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.body(context)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (items) => items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyText, style: AppTypography.caption(context)),
            )
          : Column(children: [for (final i in items) builder(i)]),
    );
  }

  Widget _anomalyCard(BuildContext context, WidgetRef ref, AnomalyEntity a) {
    final ratio = (a.ratioPercent / 100).toStringAsFixed(1);
    final high = a.severity == 'high';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (high ? AppColors.danger : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: Text(
                    'Gấp $ratio lần mức thường',
                    style: TextStyle(
                      color: high ? AppColors.danger : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (a.transactedAt != null)
                  Text(_timeFormat.format(a.transactedAt!), style: AppTypography.caption(context).copyWith(fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 10),
            Text(_kindTitle(a), style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Khoản ${a.formattedAmount}, trong khi mức thường là ${a.formattedTypical}.',
              style: AppTypography.caption(context).copyWith(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (a.isResolved)
              Text(
                'Đã phản hồi: ${_resolutionLabel(a.resolution!)}',
                style: AppTypography.caption(context).copyWith(color: AppColors.safe, fontWeight: FontWeight.w600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final r in const ['normal', 'one_off', 'wrong_entry', 'suspicious'])
                    ActionChip(
                      label: Text(_resolutionLabel(r)),
                      onPressed: () => _anomalyFeedback(context, ref, a.id, r),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(BuildContext context, WidgetRef ref, ForecastAlertEntity a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              a.body,
              style: AppTypography.caption(context).copyWith(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_timeFormat.format(a.createdAt), style: AppTypography.caption(context).copyWith(fontSize: 11.5)),
                const Spacer(),
                if (a.markedInaccurate)
                  Text('Đã báo không chính xác', style: AppTypography.caption(context).copyWith(color: AppColors.warning))
                else
                  TextButton(
                    onPressed: () => _alertFeedback(context, ref, a.id),
                    child: const Text('Báo không chính xác'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
