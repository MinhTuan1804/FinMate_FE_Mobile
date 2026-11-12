import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// B7 — Ngưỡng cảnh báo ngân sách: chỉ T1/T2 cá nhân (slider) + lưu/xóa-dùng-mặc-định.
/// Không có ngưỡng theo từng hũ hay 2 toggle (tự khóa chi tiêu, AI tự cân đối) — những cái đó
/// ngoài phạm vi vì [AlertThresholdSettingsEntity] không hỗ trợ.
class AlertThresholdsScreen extends ConsumerStatefulWidget {
  const AlertThresholdsScreen({super.key});

  @override
  ConsumerState<AlertThresholdsScreen> createState() => _AlertThresholdsScreenState();
}

class _AlertThresholdsScreenState extends ConsumerState<AlertThresholdsScreen> {
  int? _t1;
  int? _t2;

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
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
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
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(alertThresholdsControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Ngưỡng cảnh báo', style: GlassTypography.headlineMd()),
          actions: [
            TextButton(onPressed: _clear, child: const Text('Mặc định')),
          ],
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), style: GlassTypography.bodyMd(), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => ref.read(alertThresholdsControllerProvider.notifier).load(), child: const Text('Thử lại')),
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        GlassCard(
                          level: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NGƯỠNG CẢNH BÁO', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
                              const SizedBox(height: 8),
                              Text(
                                'Nhận nhắc nhẹ ở T1 và cảnh báo mạnh ở T2 khi chi tiêu trong hũ/tháng chạm các mốc này.',
                                style: GlassTypography.bodyMd(),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Đang áp dụng: T1=${t.t1Pct}% · T2=${t.t2Pct}% (nguồn: ${t.source})',
                                key: const ValueKey('threshold-effective'),
                                style: GlassTypography.bodySm(),
                              ),
                              if (t.methodName != null) Text('Theo cách: ${t.methodName}', style: GlassTypography.bodySm()),
                              Text(
                                'Mặc định hệ thống: T1=${t.systemDefault.t1Pct}% · T2=${t.systemDefault.t2Pct}%',
                                style: GlassTypography.bodySm(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ThresholdSlider(
                                key: const ValueKey('threshold-t1-input'),
                                label: 'T1 — Nhắc nhẹ',
                                value: _t1 ?? t.t1Pct,
                                min: 1,
                                max: 98,
                                color: GlassColors.warning,
                                onChanged: (v) => setState(() => _t1 = v),
                              ),
                              const SizedBox(height: 20),
                              _ThresholdSlider(
                                key: const ValueKey('threshold-t2-input'),
                                label: 'T2 — Cảnh báo mạnh',
                                value: _t2 ?? t.t2Pct,
                                min: 2,
                                max: 99,
                                color: GlassColors.danger,
                                onChanged: (v) => setState(() => _t2 = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassBottomDock(
                    actions: [
                      GlassSecondaryButton(label: 'Xóa, dùng mặc định', onPressed: _clear),
                      GlassPrimaryButton(key: const ValueKey('threshold-save'), label: 'Lưu cấu hình', onPressed: _save),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ThresholdSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
            Text('$value%', style: GlassTypography.labelNumeric(color: color)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: GlassColors.secondarySurface,
            thumbColor: Colors.white,
            overlayColor: color.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 6,
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$min%', style: GlassTypography.bodySm()),
            Text('$max%', style: GlassTypography.bodySm()),
          ],
        ),
      ],
    );
  }
}
