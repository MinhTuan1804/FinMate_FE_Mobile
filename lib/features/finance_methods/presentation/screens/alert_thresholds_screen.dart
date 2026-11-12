import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_providers.dart';
import 'package:finmate/features/finance_methods/presentation/widgets/finance_widgets.dart';

/// Màn NGƯỠNG CẢNH BÁO NGÂN SÁCH: khi chi tiêu chạm T1% hạn mức thì nhắc nhẹ, chạm T2% thì cảnh báo mạnh, vượt 100% thì báo vượt (cố định).
/// Ngưỡng theo thứ tự: cách quản lý đang dùng (nếu cách đó có T1/T2) → ngưỡng cá nhân của bạn → mặc định của FinMate.
/// Đang dùng cách có ngưỡng riêng thì chỉnh ở "Cách quản lý của tôi"; không thì chỉnh ngay đây và đây luôn có mặc định để quay về.
class AlertThresholdsScreen extends ConsumerWidget {
  const AlertThresholdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(alertThresholdsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Ngưỡng cảnh báo ngân sách', style: AppTypography.h3(context))),
      body: AmbientGlassBackground(
        child: SafeArea(
          child: settings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => FinanceFailure(message: errorMessage(error), onRetry: () => ref.invalidate(alertThresholdsProvider)),
            data: (data) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'FinMate nhắc bạn khi chi tiêu chạm một phần hạn mức ngân sách. Vượt hết hạn mức (100%) luôn được báo.',
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                ZenvestHeroDeck(
                  peekBadgeText: 'ALERT',
                  child: _CurrentCard(settings: data),
                ),
                const SizedBox(height: AppSpacing.md),
                ZenvestSurfaceSheet(
                  child: data.followsMethod
                      ? _MethodNotice(settings: data)
                      : _ThresholdEditor(key: ValueKey('${data.source}-${data.effective.t1}-${data.effective.t2}'), settings: data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.settings});

  final AlertThresholdSettings settings;

  String get _sourceText => switch (settings.source) {
        AlertThresholdSettings.sourceMethod => 'Theo cách quản lý "${settings.methodName ?? settings.methodCode ?? ''}"',
        AlertThresholdSettings.sourcePersonal => 'Theo cài đặt của bạn',
        _ => 'Theo mặc định của FinMate',
      };

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      key: const Key('current_thresholds'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinanceSectionLabel('Đang áp dụng'),
          const SizedBox(height: AppSpacing.sm),
          _Row(label: 'Nhắc nhẹ (T1)', value: '${settings.effective.t1}%', valueKey: const Key('value_t1')),
          _Row(label: 'Cảnh báo mạnh (T2)', value: '${settings.effective.t2}%', valueKey: const Key('value_t2')),
          const _Row(label: 'Vượt hạn mức', value: '100% (cố định)'),
          const SizedBox(height: AppSpacing.sm),
          Text(_sourceText, key: const Key('threshold_source'), style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.body(context))),
          Text(value, key: valueKey, style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// Đang dùng cách quản lý có ngưỡng riêng: không chỉnh ở đây, chỉ chỉ đường tới chỗ chỉnh.
class _MethodNotice extends StatelessWidget {
  const _MethodNotice({required this.settings});

  final AlertThresholdSettings settings;

  @override
  Widget build(BuildContext context) {
    final personal = settings.personal;
    return FinanceCard(
      key: const Key('method_notice'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ngưỡng đang theo cách quản lý "${settings.methodName ?? ''}". Muốn đổi, chỉnh tham số ngưỡng trong "Cách quản lý của tôi".',
            style: AppTypography.body(context),
          ),
          if (personal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ngưỡng cá nhân của bạn (${personal.t1}% / ${personal.t2}%) vẫn được giữ và sẽ dùng lại khi bạn ngừng dùng cách này.',
              style: AppTypography.caption(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            key: const Key('open_my_methods'),
            onPressed: () => context.push('/finance-methods'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Mở Cách quản lý của tôi'),
          ),
        ],
      ),
    );
  }
}

class _ThresholdEditor extends ConsumerStatefulWidget {
  const _ThresholdEditor({super.key, required this.settings});

  final AlertThresholdSettings settings;

  @override
  ConsumerState<_ThresholdEditor> createState() => _ThresholdEditorState();
}

class _ThresholdEditorState extends ConsumerState<_ThresholdEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _t1 = TextEditingController(text: '${widget.settings.effective.t1}');
  late final _t2 = TextEditingController(text: '${widget.settings.effective.t2}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _t1.dispose();
    _t2.dispose();
    super.dispose();
  }

  int? get _t1Value => int.tryParse(_t1.text.trim());
  int? get _t2Value => int.tryParse(_t2.text.trim());

  bool get _dirty => _t1Value != widget.settings.effective.t1 || _t2Value != widget.settings.effective.t2;

  String? _validateT1(String? text) {
    final value = int.tryParse((text ?? '').trim());
    if (value == null) return 'Nhập một số';
    if (value < 1 || value > 98) return 'Từ 1% đến 98%';
    return null;
  }

  String? _validateT2(String? text) {
    final value = int.tryParse((text ?? '').trim());
    if (value == null) return 'Nhập một số';
    if (value < 2 || value > 99) return 'Từ 2% đến 99%';
    final t1 = _t1Value;
    if (t1 != null && t1 >= value) return 'Phải lớn hơn ngưỡng nhắc nhẹ';
    return null;
  }

  Future<void> _run(Future<AlertThresholdSettings> Function() action, String doneMessage) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(alertThresholdsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMessage)));
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = errorMessage(error);
          _saving = false;
        });
      }
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final t1 = _t1Value!;
    final t2 = _t2Value!;
    _run(() => ref.read(financeMethodsRepositoryProvider).setAlertThresholds(t1, t2), 'Đã lưu ngưỡng cảnh báo.');
  }

  void _reset() => _run(() => ref.read(financeMethodsRepositoryProvider).clearAlertThresholds(), 'Đã quay về mặc định.');

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final system = settings.systemDefault;
    return FinanceCard(
      key: const Key('threshold_editor'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FinanceSectionLabel('Ngưỡng của bạn'),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('threshold_t1'),
              controller: _t1,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(labelText: 'Nhắc nhẹ khi đã dùng (T1)', suffixText: '% hạn mức', helperText: 'Từ 1% đến 98%'),
              validator: _validateT1,
              onChanged: (_) => setState(() => _formKey.currentState?.validate()),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('threshold_t2'),
              controller: _t2,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(labelText: 'Cảnh báo mạnh khi đã dùng (T2)', suffixText: '% hạn mức', helperText: 'Từ 2% đến 99%, lớn hơn T1'),
              validator: _validateT2,
              onChanged: (_) => setState(() => _formKey.currentState?.validate()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Mặc định của FinMate: ${system.t1}% / ${system.t2}%. Mức vượt hạn mức luôn là 100%.', style: AppTypography.caption(context)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(_error!, key: const Key('threshold_error'), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (settings.personal != null)
                  TextButton(key: const Key('reset_thresholds'), onPressed: _saving ? null : _reset, child: Text('Dùng mặc định (${system.t1}% / ${system.t2}%)')),
                const Spacer(),
                ElevatedButton(
                  key: const Key('save_thresholds'),
                  onPressed: _saving || !_dirty ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAction(context),
                    foregroundColor: AppColors.onPrimaryAction(context),
                    minimumSize: const Size(120, 48),
                    shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                  ),
                  child: _saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimaryAction(context)))
                      : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
