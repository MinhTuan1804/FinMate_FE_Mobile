import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/finance_methods/domain/financial_plan.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/financial_plan_controller.dart';
import 'package:finmate/features/forecast/data/forecast_repository.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_text_field.dart';

/// B8 — "Kế hoạch tháng của bạn": bản nháp backend tính từ khảo sát + cách quản lý chính (thu → cố định → chi → dư).
/// Người dùng sửa từng hạn mức (số dư tính lại ngay trên máy), rồi "Áp dụng" để lưu thành ngân sách theo danh mục hoặc "Để sau".
class FinancialPlanScreen extends ConsumerStatefulWidget {
  const FinancialPlanScreen({super.key});

  @override
  ConsumerState<FinancialPlanScreen> createState() => _FinancialPlanScreenState();
}

class _FinancialPlanScreenState extends ConsumerState<FinancialPlanScreen> {
  /// Hạn mức đang sửa theo slug; danh mục chưa sửa dùng hạn mức đề xuất.
  final Map<String, int> _limits = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _applying = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(FinancialPlanLineEntity line) => _controllers.putIfAbsent(
        line.slug,
        () => TextEditingController(text: formatAmountDigits(BigInt.from(line.limitVnd))),
      );

  void _editLimit(FinancialPlanLineEntity line, String text) {
    final value = parseAmountInput(text, allowZero: true);
    setState(() => _limits[line.slug] = value?.toInt() ?? 0);
  }

  void _toMyMethods() => context.pushReplacement('/finance-methods/my-methods');

  Future<void> _apply(FinancialPlanEntity plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final items = [
      for (final line in plan.categories)
        if ((_limits[line.slug] ?? line.limitVnd) > 0)
          CategoryBudgetItemInput(categoryId: line.categoryId, limitCents: BigInt.from(_limits[line.slug] ?? line.limitVnd)),
    ];
    setState(() => _applying = true);
    try {
      await ref.read(forecastRepositoryProvider).applyCategoryBudgets(items);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Đã đặt hạn mức cho ${items.length} danh mục.')));
      _toMyMethods();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financialPlanDraftProvider);
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(context, title: 'Kế hoạch tháng của bạn'),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _PlanError(error: e, onRetry: () => ref.invalidate(financialPlanDraftProvider)),
            data: (plan) => Column(
              children: [
                Expanded(child: _planBody(plan)),
                GlassBottomDock(
                  actions: [
                    GlassGhostButton(
                      key: const ValueKey('plan-later'),
                      label: 'Để sau',
                      onPressed: _applying ? null : _toMyMethods,
                    ),
                    GlassPrimaryButton(
                      key: const ValueKey('plan-apply'),
                      label: 'Áp dụng',
                      loading: _applying,
                      onPressed: _applying ? null : () => _apply(plan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planBody(FinancialPlanEntity plan) {
    final surplus = planSurplus(plan, _limits);
    final spend = plan.incomeVnd - surplus;
    // Thâm hụt và mức để dành tính lại theo hạn mức đang sửa; cảnh báo "cố định vượt nhóm" giữ như backend tính.
    final fixedWarnings = plan.warnings.where((w) => w.startsWith('fixed_exceeds_group:'));
    final deficit = surplus < 0;
    final belowTarget = !deficit && surplus < plan.saveTargetVnd;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        GlassCard(
          level: 2,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(label: 'Thu nhập mỗi tháng', amount: plan.incomeVnd),
              _SummaryRow(label: 'Khoản cố định', amount: plan.fixedVnd),
              _SummaryRow(label: 'Dự kiến chi (gồm cố định)', amount: spend),
              const Divider(height: 24),
              Text('Cuối tháng dư', style: GlassTypography.bodyMd(color: GlassColors.textSecondary)),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  formatVnd(BigInt.from(surplus)),
                  key: const ValueKey('plan-surplus'),
                  style: GlassTypography.headlineMd(color: deficit ? GlassColors.danger : GlassColors.textPrimary),
                ),
              ),
              if (!deficit && plan.saveTargetVnd > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Mức nên để dành: ${formatVnd(BigInt.from(plan.saveTargetVnd))}',
                  key: const ValueKey('plan-save-target'),
                  style: GlassTypography.bodySm(color: GlassColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        for (final warning in [if (deficit) 'deficit', if (belowTarget) 'below_save_target', ...fixedWarnings]) ...[
          const SizedBox(height: 12),
          _WarningNote(
            key: ValueKey('plan-warning-${warning.split(':').first}'),
            text: financialPlanWarningText(warning, plan.groups),
            strong: warning == 'deficit',
          ),
        ],
        const SizedBox(height: 20),
        Semantics(header: true, child: Text('Hạn mức từng khoản', style: GlassTypography.headlineSm())),
        const SizedBox(height: 4),
        Text(
          'Sửa số nào thấy chưa hợp lý; số dư phía trên tính lại ngay.',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final line in plan.categories) ...[
          _LimitRow(
            key: ValueKey('plan-limit-${line.slug}'),
            line: line,
            controller: _controllerFor(line),
            onChanged: (text) => _editLimit(line, text),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int amount;

  const _SummaryRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GlassTypography.bodyMd(color: GlassColors.textSecondary))),
          Text(formatVnd(BigInt.from(amount)), style: GlassTypography.bodyMd()),
        ],
      ),
    );
  }
}

class _WarningNote extends StatelessWidget {
  final String text;
  final bool strong;

  const _WarningNote({super.key, required this.text, required this.strong});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(16),
      child: Text(text, style: GlassTypography.bodyMd(color: strong ? GlassColors.danger : GlassColors.textPrimary)),
    );
  }
}

/// Một danh mục: tên làm nhãn, ô sửa hạn mức (bàn phím số, tự thêm dấu chấm), ghi chú nếu kế hoạch đã giảm so với mức khai.
class _LimitRow extends StatelessWidget {
  final FinancialPlanLineEntity line;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _LimitRow({super.key, required this.line, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassTextField(
          controller: controller,
          label: line.name,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          onChanged: onChanged,
        ),
        if (line.reducedByVnd > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Đã giảm ${formatVnd(BigInt.from(line.reducedByVnd))} so với mức bạn khai',
            style: GlassTypography.bodySm(color: GlassColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Lỗi tải bản nháp: thiếu thu nhập hoặc chưa chọn cách quản lý thì chỉ đường để bổ sung; lỗi khác thì cho thử lại.
class _PlanError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _PlanError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final code = error is ApiException ? (error as ApiException).code : null;
    final (message, action) = switch (code) {
      'FINANCE_PLAN_NO_INCOME' => (
          'Cần biết thu nhập hằng tháng của bạn để lập kế hoạch.',
          GlassPrimaryButton(
            key: const ValueKey('plan-enter-income'),
            label: 'Nhập thu nhập',
            onPressed: () => context.push('/survey'),
          ),
        ),
      'FINANCE_PLAN_NO_ACTIVE_METHOD' => (
          'Hãy chọn một cách quản lý tài chính trước.',
          GlassPrimaryButton(
            key: const ValueKey('plan-choose-method'),
            label: 'Chọn cách quản lý',
            onPressed: () => context.push('/finance-methods'),
          ),
        ),
      _ => (errorMessage(error), GlassSecondaryButton(label: 'Thử lại', onPressed: onRetry)),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
