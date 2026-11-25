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
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

enum _Tab { all, open, confirmed }

const _anomalyKindLabel = {
  'category_spike': 'Chi tiêu danh mục tăng đột biến',
  'merchant_spike': 'Chi tiêu tăng đột biến',
  'duplicate': 'Nghi trùng giao dịch',
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

  void _notAvailableYet(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what sắp có.')));
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
            child: const Icon(LucideIcons.triangleAlert, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GlassBadge(text: 'AI PHÁT HIỆN', color: GlassColors.warning),
                    const SizedBox(width: 8),
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
              style: GlassTypography.bodyMd(color: selected ? Colors.white : GlassColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
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

  Widget _alertCard(ForecastAlertEntity alert) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GlassBadge(text: alert.kind, color: GlassColors.warning),
              GlassBadge(text: alert.markedInaccurate ? 'Đã phản hồi' : 'Chưa giải quyết', color: alert.markedInaccurate ? GlassColors.success : GlassColors.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Text(alert.title, style: GlassTypography.headlineSm()),
          const SizedBox(height: 6),
          Text(alert.body, style: GlassTypography.bodyMd()),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 0,
            children: [
              Text('Phản hồi độ chính xác:', style: GlassTypography.bodySm()),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => _notAvailableYet('Phản hồi "Hữu ích"'),
                child: Text('Hữu ích', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
              ),
              TextButton(
                onPressed: alert.markedInaccurate ? null : () => ref.read(forecastAlertsControllerProvider.notifier).markInaccurate(alert.id),
                child: Text('Không chính xác', style: GlassTypography.bodySm(color: GlassColors.danger)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _notAvailableYet('Điều chỉnh hạn mức'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlassColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
              ),
              icon: const Icon(LucideIcons.slidersHorizontal, size: 16),
              label: const Text('Điều chỉnh hạn mức'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anomalyCard(AnomalyEntity anomaly) {
    final title = _anomalyKindLabel[anomaly.kind] ?? 'Giao dịch bất thường';
    final dateText = anomaly.transactedAt == null ? '' : ' ngày ${DateFormat('dd/MM').format(anomaly.transactedAt!)}';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GlassBadge(text: title, color: GlassColors.accentDustyRose),
              if (anomaly.merchantName != null) GlassBadge(text: anomaly.merchantName!, color: GlassColors.slateAnchor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '-${anomaly.formattedAmount}$dateText (thường khoảng ${anomaly.formattedTypical}).',
            style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (anomaly.isResolved)
            GlassBadge(text: 'Đã xác nhận: ${_resolutionLabel[anomaly.resolution] ?? anomaly.resolution}', color: GlassColors.success)
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // Chưa có màn chi tiết 1 giao dịch riêng — trỏ vào Lịch sử giao dịch (D1), cùng cách
              // C3 đã làm khi thiếu màn đích thật.
              onPressed: () => context.push('/transactions'),
              child: Text('Xem chứng từ', style: GlassTypography.bodyMd(color: GlassColors.accentSkyBlue)),
            ),
          ),
        ],
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
                        text: 'Cài đặt dự báo',
                        style: GlassTypography.bodySm(color: GlassColors.accentSkyBlue).copyWith(fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()..onTap = () => context.push('/forecast-settings'),
                      ),
                      const TextSpan(text: ' để tùy chỉnh mức độ nhạy cảm báo theo nhu cầu thực tế của bạn.'),
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
