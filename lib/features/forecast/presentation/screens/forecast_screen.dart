import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/forecast/data/forecast_repository.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';

final _dayFormat = DateFormat('dd/MM');

String _confidenceLabel(String value) => switch (value) {
      'normal' => 'Bình thường',
      'low' => 'Thấp (chưa đủ dữ liệu)',
      _ => value,
    };

String _basisLabel(String value) => switch (value) {
      'history' => 'Lịch sử chi tiêu',
      'budget' => 'Ngân sách đã đặt',
      'average' => 'Trung bình chi tiêu',
      'none' => 'Chưa có dữ liệu',
      _ => value,
    };

String _periodBasisLabel(String value) => switch (value) {
      'next_income' => 'Tới kỳ lương kế tiếp',
      'month_end' => 'Tới cuối tháng',
      _ => value,
    };

String _budgetStatusLabel(String value) => switch (value) {
      'ok' => 'Trong hạn mức',
      'at_risk' => 'Có thể vượt',
      'over' => 'Đã vượt hạn mức',
      _ => value,
    };

Color _budgetStatusColor(String value) => switch (value) {
      'over' => AppColors.danger,
      'at_risk' => AppColors.warning,
      _ => AppColors.safe,
    };

String _budgetBasisLabel(String value) => switch (value) {
      'pace' => 'Theo nhịp chi tháng này',
      'history' => 'Theo thói quen danh mục',
      _ => value,
    };

String _alertKindLabel(String value) => switch (value) {
      'low_balance' => 'Số dư thấp',
      'budget_risk' => 'Rủi ro ngân sách',
      'bill_due' => 'Hóa đơn đến hạn',
      'bill_status_check' => 'Kiểm tra hóa đơn quá hạn',
      'income_late' => 'Thu nhập trễ',
      'price_change' => 'Thay đổi giá',
      'anomaly' => 'Bất thường',
      'group_budget' => 'Ngân sách nhóm',
      'group_goal' => 'Mục tiêu nhóm',
      _ => value,
    };

String _alertStatusLabel(String value) => switch (value) {
      'pending' => 'Đang hoãn (giờ yên lặng)',
      'sent' => 'Đã gửi',
      _ => value,
    };

String _anomalyKindLabel(String value) => switch (value) {
      'category_spike' => 'Cao bất thường theo danh mục',
      'merchant_spike' => 'Cao bất thường theo nơi nhận',
      'duplicate' => 'Có thể bị ghi trùng',
      _ => value,
    };

String _anomalyResolutionLabel(String value) => switch (value) {
      'normal' => 'Bình thường',
      'one_off' => 'Chi một lần',
      'wrong_entry' => 'Nhập sai',
      'suspicious' => 'Giao dịch lạ',
      _ => value,
    };

String _goalStatusLabel(String value) => switch (value) {
      'active' => 'Đang thực hiện',
      'completed' => 'Đã hoàn thành',
      'cancelled' => 'Đã hủy',
      _ => value,
    };

String _forecastStatusLabel(String value) => switch (value) {
      'reached' => 'Đã đạt mục tiêu',
      'unreachable' => 'Khó đạt với tốc độ hiện tại',
      'no_deadline' => 'Chưa đặt hạn chót',
      'on_track' => 'Đang đúng tiến độ',
      'behind' => 'Có thể không kịp hạn',
      _ => value,
    };

Color _forecastStatusColor(String value) => switch (value) {
      'reached' => AppColors.safe,
      'on_track' => AppColors.safe,
      'behind' => AppColors.warning,
      'unreachable' => AppColors.danger,
      _ => AppColors.secondary,
    };

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  /// Kết quả thử kịch bản gần nhất (null = đang hiện dự báo thật, không giả định gì).
  CashflowForecastEntity? _scenarioResult;
  bool _scenarioBusy = false;

  /// Theo cùng [AnomaliesController.openOnly], chỉ để SegmentedButton rebuild đúng khi bấm.
  bool _anomaliesOpenOnly = true;

  /// categoryId đang chờ áp hạn mức đề xuất (null = không có cái nào đang chạy).
  String? _categoryApplyBusyId;

  /// Mục tiêu đang chọn để xem dự báo (null = chưa chọn, mặc định lấy mục tiêu đầu tiên).
  String? _selectedGoalId;

  /// Kết quả thử mức góp giả định gần nhất (null = đang hiện dự báo thật theo lịch sử góp).
  GoalForecastEntity? _goalScenarioResult;
  bool _goalScenarioBusy = false;

  void _refresh() {
    ref.invalidate(cashflowForecastProvider);
    ref.invalidate(safeToSpendProvider);
    ref.invalidate(budgetForecastProvider);
    ref.invalidate(incomeForecastProvider);
    ref.invalidate(forecastAlertsControllerProvider);
    ref.invalidate(anomaliesControllerProvider);
    ref.invalidate(categoryForecastControllerProvider);
    if (_selectedGoalId != null) ref.invalidate(goalForecastProvider(_selectedGoalId!));
    setState(() {
      _scenarioResult = null;
      _anomaliesOpenOnly = true;
      _goalScenarioResult = null;
    });
  }

  Future<void> _sendAnomalyFeedback(String anomalyId, String resolution) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(anomaliesControllerProvider.notifier).sendFeedback(anomalyId, resolution);
      if (result.guidance != null && mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Giao dịch lạ'),
            content: Text(result.guidance!),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đã hiểu'))],
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _applySuggestedBudget(CategoryForecastItemEntity item) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _categoryApplyBusyId = item.categoryId);
    try {
      final applied = await ref.read(categoryForecastControllerProvider.notifier).applySuggested(item);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(applied.isNow
            ? 'Đã tạo ngân sách ${applied.formattedLimit} cho ${item.categoryName}, áp dụng ngay.'
            : 'Đã đặt hạn mức mới ${applied.formattedLimit} cho ${item.categoryName}, áp dụng từ kỳ sau.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _categoryApplyBusyId = null);
    }
  }

  Future<void> _openGoalScenario(String goalId) async {
    final amount = await showDialog<BigInt>(context: context, builder: (_) => const _GoalScenarioDialog());
    if (amount == null || !mounted) return;
    setState(() => _goalScenarioBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(forecastRepositoryProvider).getGoalForecast(goalId, scenarioMonthlyCents: amount);
      if (!mounted) return;
      setState(() => _goalScenarioResult = result);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _goalScenarioBusy = false);
    }
  }

  Future<void> _openScenario() async {
    final item = await showDialog<ScenarioItemInput>(context: context, builder: (_) => const _ScenarioDialog());
    if (item == null || !mounted) return;
    setState(() => _scenarioBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(forecastRepositoryProvider).runScenario(items: [item]);
      if (!mounted) return;
      setState(() => _scenarioResult = result);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _scenarioBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashflowAsync = ref.watch(cashflowForecastProvider);
    final spendableAsync = ref.watch(safeToSpendProvider);
    final budgetsAsync = ref.watch(budgetForecastProvider);
    final incomeAsync = ref.watch(incomeForecastProvider);
    final alertsAsync = ref.watch(forecastAlertsControllerProvider);
    final anomaliesAsync = ref.watch(anomaliesControllerProvider);
    final categoryForecastAsync = ref.watch(categoryForecastControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dự báo tài chính'),
        actions: [
          IconButton(
            key: const ValueKey('forecast-settings-button'),
            onPressed: () => context.push('/forecast-settings'),
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Cài đặt dự báo',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildCashflowSection(context, cashflowAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildSpendableSection(context, spendableAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildBudgetsSection(context, budgetsAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildIncomeSection(context, incomeAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildAlertsSection(context, alertsAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildAnomaliesSection(context, anomaliesAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildCategoriesSection(context, categoryForecastAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildGoalSection(context),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCashflowSection(BuildContext context, AsyncValue<CashflowForecastEntity> async) {
    return _sectionCard(
      title: 'Dự báo dòng tiền',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (real) {
          final shown = _scenarioResult ?? real;
          final isScenario = _scenarioResult != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isScenario)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Đang xem kịch bản giả định (chưa lưu)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ),
              Text('${_dayFormat.format(shown.from)} - ${_dayFormat.format(shown.to)}', style: AppTypography.caption(context)),
              const SizedBox(height: 4),
              Text('Số dư đầu kỳ: ${shown.formattedStartBalance}'),
              Text('Số dư dự kiến cuối kỳ: ${shown.formattedEndBalance}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Thấp nhất: ${shown.formattedLowestBalance} (ngày ${_dayFormat.format(shown.lowestDay)})'),
              const SizedBox(height: 4),
              Text('Độ tin cậy: ${_confidenceLabel(shown.confidence)} · Cơ sở: ${_basisLabel(shown.basis)}', style: AppTypography.caption(context)),
              if (shown.mainCauses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nguyên nhân chính', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                for (final cause in shown.mainCauses)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• ${cause.label}: ${cause.formattedAmount}', style: AppTypography.caption(context)),
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  TextButton.icon(
                    key: const ValueKey('forecast-scenario-button'),
                    onPressed: _scenarioBusy ? null : _openScenario,
                    icon: const Icon(LucideIcons.plusCircle, size: 16),
                    label: const Text('Thử kịch bản'),
                  ),
                  if (isScenario)
                    TextButton(
                      key: const ValueKey('forecast-reset-scenario'),
                      onPressed: () => setState(() => _scenarioResult = null),
                      child: const Text('Xem lại dự báo gốc'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpendableSection(BuildContext context, AsyncValue<SafeToSpendEntity> async) {
    return _sectionCard(
      title: 'Số tiền có thể chi',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (spendable) {
          final overBudget = spendable.hasShortfall;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_periodBasisLabel(spendable.periodBasis), style: AppTypography.caption(context)),
              Text('${_dayFormat.format(spendable.periodStart)} - ${_dayFormat.format(spendable.periodEnd)} (còn ${spendable.daysRemaining} ngày)',
                  style: AppTypography.caption(context)),
              const SizedBox(height: 8),
              Text(
                overBudget ? 'Thiếu ${spendable.formattedShortfall}' : 'Có thể chi: ${spendable.formattedSpendable}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: overBudget ? AppColors.danger : AppColors.safe),
              ),
              if (!overBudget) Text('~${spendable.formattedPerDay} / ngày', style: AppTypography.caption(context)),
              const SizedBox(height: 8),
              _spendableLine('Số dư hiện có', spendable.balanceCents),
              _spendableLine('Thu nhập dự kiến', spendable.expectedIncomeCents),
              _spendableLine('Hóa đơn sắp tới', -spendable.upcomingBillsCents),
              _spendableLine('Dành cho mục tiêu', -spendable.goalSetAsideCents),
              _spendableLine('Khoản dự phòng', -spendable.reserveCents),
              if (spendable.accounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Theo ví', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                for (final a in spendable.accounts)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${a.name}: ${a.formattedBalance}', style: AppTypography.caption(context)),
                  ),
              ],
              if (spendable.bills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Hóa đơn sắp tới', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                for (final b in spendable.bills)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${_dayFormat.format(b.date)} · ${b.label}: ${b.formattedAmount}', style: AppTypography.caption(context)),
                  ),
              ],
              if (spendable.goals.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Mục tiêu tiết kiệm', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                for (final g in spendable.goals)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${g.name}: để dành ${g.formattedSetAside}', style: AppTypography.caption(context)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBudgetsSection(BuildContext context, AsyncValue<List<BudgetForecastEntity>> async) {
    return _sectionCard(
      title: 'Ngân sách dự kiến',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Text('Chưa có ngân sách nào được đặt cho tháng này.', style: AppTypography.caption(context));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in budgets)
                Padding(
                  key: ValueKey('budget-forecast-${b.budgetId}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(b.isTotal ? 'Tổng chi' : (b.categoryName ?? 'Không rõ danh mục'),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _budgetStatusColor(b.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_budgetStatusLabel(b.status),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _budgetStatusColor(b.status))),
                          ),
                        ],
                      ),
                      Text('Đã chi ${b.formattedSpent} / ${b.formattedLimit} (${b.projectedPercent}% dự kiến)',
                          style: AppTypography.caption(context)),
                      Text('Dự kiến cuối kỳ: ${b.formattedProjected}', style: AppTypography.caption(context)),
                      if (!b.isOver)
                        Text('Có thể chi ${b.formattedMaxDailySpend}/ngày trong ${b.daysRemaining} ngày còn lại',
                            style: AppTypography.caption(context)),
                      Text(_budgetBasisLabel(b.basis), style: AppTypography.caption(context).copyWith(fontSize: 10)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIncomeSection(BuildContext context, AsyncValue<IncomeForecastEntity> async) {
    return _sectionCard(
      title: 'Thu nhập dự kiến',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (income) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(income.isRegular ? 'Thu nhập đều đặn (theo khoản thu định kỳ)' : 'Thu nhập không đều',
                  style: AppTypography.caption(context)),
              if (income.late.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Thu nhập trễ hạn', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600, color: AppColors.danger)),
                for (final l in income.late)
                  Padding(
                    key: ValueKey('late-income-${l.recurringItemId}'),
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${l.name}: ${l.formattedAmount} (trễ ${l.daysLate} ngày, dự kiến ${_dayFormat.format(l.expectedDate)})',
                        style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
                  ),
              ],
              if (income.upcoming.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Sắp tới', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                for (final u in income.upcoming)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${_dayFormat.format(u.date)} · ${u.label}: ${u.formattedAmount}', style: AppTypography.caption(context)),
                  ),
              ],
              if (income.irregular != null) ...[
                const SizedBox(height: 8),
                Text('Ước tính thu nhập không đều', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                Text('Mức thận trọng: ${income.irregular!.formattedConservativeMonthly}/tháng (dựa trên ${income.irregular!.monthsUsed} tháng gần nhất)',
                    style: AppTypography.caption(context)),
                Text('Đã nhận tháng này: ${income.irregular!.formattedReceivedThisMonth}', style: AppTypography.caption(context)),
              ],
              if (income.upcoming.isEmpty && income.late.isEmpty && income.irregular == null)
                Text('Chưa có dữ liệu thu nhập để dự báo.', style: AppTypography.caption(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, AsyncValue<List<ForecastAlertEntity>> async) {
    return _sectionCard(
      title: 'Cảnh báo dự báo',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(forecastAlertsControllerProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Text('Chưa có cảnh báo nào.', style: AppTypography.caption(context));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in alerts)
                Padding(
                  key: ValueKey('forecast-alert-${a.id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(_alertStatusLabel(a.status), style: AppTypography.caption(context)),
                        ],
                      ),
                      Text(a.body, style: AppTypography.caption(context)),
                      Text('${_alertKindLabel(a.kind)} · ${_dayFormat.format(a.createdAt)}',
                          style: AppTypography.caption(context).copyWith(fontSize: 10)),
                      if (a.markedInaccurate)
                        Text('Đã báo không chính xác', style: AppTypography.caption(context).copyWith(color: AppColors.warning))
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: ValueKey('alert-mark-inaccurate-${a.id}'),
                            onPressed: () => ref.read(forecastAlertsControllerProvider.notifier).markInaccurate(a.id),
                            child: const Text('Báo không chính xác'),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnomaliesSection(BuildContext context, AsyncValue<List<AnomalyEntity>> async) {
    return _sectionCard(
      title: 'Khoản bất thường',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            key: const ValueKey('anomalies-open-toggle'),
            segments: const [
              ButtonSegment(value: true, label: Text('Đang mở')),
              ButtonSegment(value: false, label: Text('Tất cả')),
            ],
            selected: {_anomaliesOpenOnly},
            onSelectionChanged: (s) {
              final value = s.first;
              setState(() => _anomaliesOpenOnly = value);
              ref.read(anomaliesControllerProvider.notifier).setOpenOnly(value);
            },
          ),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
                TextButton(onPressed: () => ref.invalidate(anomaliesControllerProvider), child: const Text('Thử lại')),
              ],
            ),
            data: (anomalies) {
              if (anomalies.isEmpty) {
                return Text(
                  _anomaliesOpenOnly ? 'Không có khoản bất thường đang mở.' : 'Chưa có khoản bất thường nào.',
                  style: AppTypography.caption(context),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in anomalies)
                    Padding(
                      key: ValueKey('anomaly-${a.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_anomalyKindLabel(a.kind)}${a.merchantName != null ? ' · ${a.merchantName}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${a.formattedAmount} (gấp ${(a.ratioPercent / 100).toStringAsFixed(1)} lần mức thường: ${a.formattedTypical})',
                            style: AppTypography.caption(context),
                          ),
                          if (a.transactedAt != null)
                            Text(_dayFormat.format(a.transactedAt!), style: AppTypography.caption(context).copyWith(fontSize: 10)),
                          if (a.isResolved)
                            Text('Đã phản hồi: ${_anomalyResolutionLabel(a.resolution!)}',
                                style: AppTypography.caption(context).copyWith(color: AppColors.safe))
                          else
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final r in const ['normal', 'one_off', 'wrong_entry', 'suspicious'])
                                  OutlinedButton(
                                    key: ValueKey('anomaly-feedback-$r-${a.id}'),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                    onPressed: () => _sendAnomalyFeedback(a.id, r),
                                    child: Text(_anomalyResolutionLabel(r), style: const TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context, AsyncValue<CategoryForecastEntity> async) {
    return _sectionCard(
      title: 'Dự báo chi tiêu theo danh mục',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(categoryForecastControllerProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (forecast) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final m in forecast.availableMonths)
                    ChoiceChip(
                      key: ValueKey('category-month-$m'),
                      label: Text(m),
                      selected: forecast.month == m,
                      onSelected: (_) => ref.read(categoryForecastControllerProvider.notifier).setMonth(m),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!forecast.enoughHistory)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Chưa đủ dữ liệu lịch sử (mới có ${forecast.monthsWithData} tháng) — độ tin cậy thấp.',
                    style: AppTypography.caption(context).copyWith(color: AppColors.warning),
                  ),
                ),
              Text(
                'Tổng dự kiến: ${forecast.formattedProjectedTotal} (tháng trước: ${forecast.formattedPreviousMonthTotal})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (forecast.items.isEmpty)
                Text('Chưa có dữ liệu để dự báo.', style: AppTypography.caption(context))
              else
                for (final item in forecast.items)
                  Padding(
                    key: ValueKey('category-forecast-${item.categoryId ?? 'uncategorized'}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.categoryName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          'Dự kiến ${item.formattedProjected} (tháng trước ${item.formattedPreviousMonth}'
                          '${item.changePercent != null ? ', ${item.changePercent! > 0 ? '+' : ''}${item.changePercent}%' : ''})',
                          style: AppTypography.caption(context),
                        ),
                        Text(
                          '${_basisLabel(item.basis)} · Độ tin cậy: ${_confidenceLabel(item.confidence)}',
                          style: AppTypography.caption(context).copyWith(fontSize: 10),
                        ),
                        if (item.currentLimitCents != null)
                          Text('Ngân sách hiện tại: ${formatVnd(item.currentLimitCents!)}', style: AppTypography.caption(context)),
                        if (item.suggestedLimitCents != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: OutlinedButton(
                              key: ValueKey('apply-category-budget-${item.categoryId}'),
                              onPressed: _categoryApplyBusyId == item.categoryId ? null : () => _applySuggestedBudget(item),
                              child: Text('Dùng ${formatVnd(item.suggestedLimitCents!)} làm ngân sách'),
                            ),
                          ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoalSection(BuildContext context) {
    final planningAsync = ref.watch(planningControllerProvider);
    return _sectionCard(
      title: 'Dự báo mục tiêu tiết kiệm',
      child: planningAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
        data: (planning) {
          final goals = planning.savingsGoals;
          if (goals.isEmpty) {
            return Text('Bạn chưa có mục tiêu tiết kiệm nào.', style: AppTypography.caption(context));
          }
          final selectedId = goals.any((g) => g.id == _selectedGoalId) ? _selectedGoalId! : goals.first.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('goal-forecast-select'),
                initialValue: selectedId,
                decoration: const InputDecoration(labelText: 'Mục tiêu'),
                items: [for (final g in goals) DropdownMenuItem(value: g.id, child: Text(g.title))],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedGoalId = v;
                    _goalScenarioResult = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildGoalForecastResult(context, selectedId),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoalForecastResult(BuildContext context, String goalId) {
    final async = ref.watch(goalForecastProvider(goalId));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      error: (e, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
          TextButton(onPressed: () => ref.invalidate(goalForecastProvider(goalId)), child: const Text('Thử lại')),
        ],
      ),
      data: (real) {
        final shown = _goalScenarioResult ?? real;
        final isScenario = _goalScenarioResult != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isScenario)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  'Đang xem theo mức góp giả định (chưa lưu)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                ),
              ),
            Text(
              'Đã để dành ${shown.formattedSaved} / ${shown.formattedTarget} (${shown.percentComplete}%) · ${_goalStatusLabel(shown.goalStatus)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${_forecastStatusLabel(shown.forecastStatus)} · Độ tin cậy: ${_confidenceLabel(shown.confidence)}',
              style: AppTypography.caption(context).copyWith(color: _forecastStatusColor(shown.forecastStatus)),
            ),
            const SizedBox(height: 4),
            Text(shown.message, style: AppTypography.caption(context)),
            Text(
              'Trung bình: ${shown.formattedAverageMonthly}/tháng · Thận trọng: ${shown.formattedConservativeMonthly}/tháng',
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  key: const ValueKey('goal-scenario-button'),
                  onPressed: _goalScenarioBusy ? null : () => _openGoalScenario(goalId),
                  icon: const Icon(LucideIcons.plusCircle, size: 16),
                  label: const Text('Thử mức góp khác'),
                ),
                if (isScenario)
                  TextButton(
                    key: const ValueKey('goal-reset-scenario'),
                    onPressed: () => setState(() => _goalScenarioResult = null),
                    child: const Text('Xem lại dự báo gốc'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _spendableLine(String label, BigInt amountCents) {
    final isNegative = amountCents < BigInt.zero;
    final display = isNegative ? amountCents * BigInt.from(-1) : amountCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption(context)),
          _AmountText(amountCents: display, negative: isNegative),
        ],
      ),
    );
  }
}

/// Hiện số tiền kèm dấu +/- để rõ chiều ảnh hưởng tới số tiền có thể chi.
class _AmountText extends StatelessWidget {
  final BigInt amountCents;
  final bool negative;
  const _AmountText({required this.amountCents, required this.negative});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${negative ? '-' : '+'}${formatVnd(amountCents)}',
      style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Hộp thoại nhập một khoản thu/chi giả định để thử kịch bản dòng tiền.
class _ScenarioDialog extends StatefulWidget {
  const _ScenarioDialog();

  @override
  State<_ScenarioDialog> createState() => _ScenarioDialogState();
}

class _ScenarioDialogState extends State<_ScenarioDialog> {
  final _amount = TextEditingController();
  final _label = TextEditingController();
  RecurringDirection _direction = RecurringDirection.outflow;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final amountValue = BigInt.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    // BE bắt buộc mỗi khoản giả định phải có tên (1-60 ký tự), không chấp nhận rỗng.
    final valid = amountValue != null && amountValue > BigInt.zero && _label.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Thử kịch bản'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<RecurringDirection>(
              segments: const [
                ButtonSegment(value: RecurringDirection.inflow, label: Text('Khoản thu')),
                ButtonSegment(value: RecurringDirection.outflow, label: Text('Khoản chi')),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('scenario-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền (₫)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('scenario-label'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const ValueKey('scenario-date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        TextButton(
          key: const ValueKey('confirm-scenario'),
          onPressed: !valid
              ? null
              : () => Navigator.pop(
                    context,
                    ScenarioItemInput(
                      date: _date,
                      amountCents: amountValue,
                      direction: _direction,
                      label: _label.text.trim(),
                    ),
                  ),
          child: const Text('Xem kết quả'),
        ),
      ],
    );
  }
}

/// Hộp thoại nhập mức góp hằng tháng giả định để thử dự báo ngày đạt mục tiêu (không lưu).
class _GoalScenarioDialog extends StatefulWidget {
  const _GoalScenarioDialog();

  @override
  State<_GoalScenarioDialog> createState() => _GoalScenarioDialogState();
}

class _GoalScenarioDialogState extends State<_GoalScenarioDialog> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amountValue = BigInt.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final valid = amountValue != null && amountValue > BigInt.zero;

    return AlertDialog(
      title: const Text('Thử mức góp khác'),
      content: TextField(
        key: const ValueKey('goal-scenario-amount'),
        controller: _amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Góp mỗi tháng (₫)'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        TextButton(
          key: const ValueKey('confirm-goal-scenario'),
          onPressed: !valid ? null : () => Navigator.pop(context, amountValue),
          child: const Text('Xem kết quả'),
        ),
      ],
    );
  }
}
