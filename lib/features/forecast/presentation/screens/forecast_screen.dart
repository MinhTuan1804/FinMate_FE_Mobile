import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/features/accounts/data/data_coverage_repository.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';
import 'package:finmate/features/accounts/presentation/widgets/data_coverage_banner.dart';
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
import 'package:finmate/core/widgets/async_action_builder.dart';

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

  /// "Số tiền có thể chi" tính lại cho cùng kịch bản (null = số thật).
  SafeToSpendEntity? _spendableScenario;
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
    if (_selectedGoalId != null)
      ref.invalidate(goalForecastProvider(_selectedGoalId!));
    setState(() {
      _scenarioResult = null;
      _spendableScenario = null;
      _anomaliesOpenOnly = true;
      _goalScenarioResult = null;
    });
  }

  Future<void> _sendAnomalyFeedback(String anomalyId, String resolution) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(anomaliesControllerProvider.notifier)
          .sendFeedback(anomalyId, resolution);
      if (result.guidance != null && mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Giao dịch lạ'),
            content: Text(result.guidance!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _applySuggestedBudget(CategoryForecastItemEntity item) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _categoryApplyBusyId = item.categoryId);
    try {
      final applied = await ref
          .read(categoryForecastControllerProvider.notifier)
          .applySuggested(item);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            applied.isNow
                ? 'Đã tạo ngân sách ${applied.formattedLimit} cho ${item.categoryName}, áp dụng ngay.'
                : 'Đã đặt hạn mức mới ${applied.formattedLimit} cho ${item.categoryName}, áp dụng từ kỳ sau.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _categoryApplyBusyId = null);
    }
  }

  Future<void> _openGoalScenario(String goalId) async {
    final amount = await showDialog<BigInt>(
      context: context,
      builder: (_) => const _GoalScenarioDialog(),
    );
    if (amount == null || !mounted) return;
    setState(() => _goalScenarioBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(forecastRepositoryProvider)
          .getGoalForecast(goalId, scenarioMonthlyCents: amount);
      if (!mounted) return;
      setState(() => _goalScenarioResult = result);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _goalScenarioBusy = false);
    }
  }

  Future<void> _openScenario() async {
    final item = await showDialog<ScenarioItemInput>(
      context: context,
      builder: (_) => const _ScenarioDialog(),
    );
    if (item == null || !mounted) return;
    setState(() => _scenarioBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(forecastRepositoryProvider);
      // Cùng một kịch bản cho cả dự báo dòng tiền lẫn "Số tiền có thể chi", để hai khối không mâu thuẫn nhau.
      final (result, spendable) = await (
        repo.runScenario(items: [item]),
        repo.runSpendableScenario(items: [item]),
      ).wait;
      if (!mounted) return;
      setState(() {
        _scenarioResult = result;
        _spendableScenario = spendable;
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
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
            // Độ phủ dữ liệu thấp hoặc mất quyền đọc thông báo: dự báo có thể thiếu giao dịch (BE đã hạ độ tin cậy). Đủ tốt thì không chiếm chỗ.
            if (ref.watch(dataCoverageProvider).valueOrNull case final coverage?
                when coverage.hasPermissionLost || coverage.level == CoverageLevel.partial || coverage.level == CoverageLevel.poor)
              if (dataCoverageBanner(context, coverage) case final banner?) ...[banner, const SizedBox(height: AppSpacing.lg)],
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
            Text(
              title,
              style: AppTypography.bodyLarge(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCashflowSection(
    BuildContext context,
    AsyncValue<CashflowForecastEntity> async,
  ) {
    return _sectionCard(
      title: 'Dự báo dòng tiền',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.danger),
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Đang xem kịch bản giả định (chưa lưu)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              Text(
                '${_dayFormat.format(shown.from)} - ${_dayFormat.format(shown.to)}',
                style: AppTypography.caption(context),
              ),
              const SizedBox(height: 4),
              Text('Số dư đầu kỳ: ${shown.formattedStartBalance}'),
              Text(
                'Số dư dự kiến cuối kỳ: ${shown.formattedEndBalance}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Thấp nhất: ${shown.formattedLowestBalance} (ngày ${_dayFormat.format(shown.lowestDay)})',
              ),
              const SizedBox(height: 4),
              Text(
                'Độ tin cậy: ${_confidenceLabel(shown.confidence)} · Cơ sở: ${_basisLabel(shown.basis)}',
                style: AppTypography.caption(context),
              ),
              if (shown.mainCauses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Nguyên nhân chính',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                for (final cause in shown.mainCauses)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• ${cause.label}: ${cause.formattedAmount}',
                      style: AppTypography.caption(context),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  AsyncActionBuilder(
                    onPressed: _scenarioBusy ? null : _openScenario,
                    builder: (_, onTap, running) => TextButton.icon(
                      key: const ValueKey('forecast-scenario-button'),
                      onPressed: onTap,
                      icon: running
                          ? const ButtonLoadingIndicator(size: 16)
                          : const Icon(LucideIcons.plusCircle, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Thử kịch bản', maxLines: 1),
                      ),
                    ),
                  ),
                  if (isScenario)
                    TextButton(
                      key: const ValueKey('forecast-reset-scenario'),
                      onPressed: () => setState(() {
                        _scenarioResult = null;
                        _spendableScenario = null;
                      }),
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

  Widget _buildSpendableSection(
    BuildContext context,
    AsyncValue<SafeToSpendEntity> async,
  ) {
    final scenario = _spendableScenario;
    return _sectionCard(
      title: scenario != null ? 'Số tiền có thể chi (kịch bản giả định)' : 'Số tiền có thể chi',
      child: (scenario != null ? AsyncValue.data(scenario) : async).when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.danger),
            ),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (spendable) => _SpendableView(
          spendable: spendable,
          basisLabel: _periodBasisLabel(spendable.periodBasis),
          dayFormat: _dayFormat,
        ),
      ),
    );
  }

  Widget _buildBudgetsSection(
    BuildContext context,
    AsyncValue<List<BudgetForecastEntity>> async,
  ) {
    return _sectionCard(
      title: 'Ngân sách dự kiến',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.danger),
            ),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Text(
              'Chưa có ngân sách nào được đặt cho tháng này.',
              style: AppTypography.caption(context),
            );
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
                            child: Text(
                              b.isTotal
                                  ? 'Tổng chi'
                                  : (b.categoryName ?? 'Không rõ danh mục'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _budgetStatusColor(
                                b.status,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _budgetStatusLabel(b.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _budgetStatusColor(b.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Đã chi ${b.formattedSpent} / ${b.formattedLimit} (${b.projectedPercent}% dự kiến)',
                        style: AppTypography.caption(context),
                      ),
                      Text(
                        'Dự kiến cuối kỳ: ${b.formattedProjected}',
                        style: AppTypography.caption(context),
                      ),
                      if (!b.isOver)
                        Text(
                          'Có thể chi ${b.formattedMaxDailySpend}/ngày trong ${b.daysRemaining} ngày còn lại',
                          style: AppTypography.caption(context),
                        ),
                      Text(
                        _budgetBasisLabel(b.basis),
                        style: AppTypography.caption(
                          context,
                        ).copyWith(fontSize: 12),
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

  Widget _buildIncomeSection(
    BuildContext context,
    AsyncValue<IncomeForecastEntity> async,
  ) {
    return _sectionCard(
      title: 'Thu nhập dự kiến',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.danger),
            ),
            TextButton(onPressed: _refresh, child: const Text('Thử lại')),
          ],
        ),
        data: (income) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                income.isRegular
                    ? 'Thu nhập đều đặn (theo khoản thu định kỳ)'
                    : 'Thu nhập không đều',
                style: AppTypography.caption(context),
              ),
              if (income.late.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Thu nhập trễ hạn',
                  style: AppTypography.caption(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
                for (final l in income.late)
                  Padding(
                    key: ValueKey('late-income-${l.recurringItemId}'),
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${l.name}: ${l.formattedAmount} (trễ ${l.daysLate} ngày, dự kiến ${_dayFormat.format(l.expectedDate)})',
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: AppColors.danger),
                    ),
                  ),
              ],
              if (income.upcoming.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Sắp tới',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                for (final u in income.upcoming)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${_dayFormat.format(u.date)} · ${u.label}: ${u.formattedAmount}',
                      style: AppTypography.caption(context),
                    ),
                  ),
              ],
              if (income.irregular != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ước tính thu nhập không đều',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Mức thận trọng: ${income.irregular!.formattedConservativeMonthly}/tháng (dựa trên ${income.irregular!.monthsUsed} tháng gần nhất)',
                  style: AppTypography.caption(context),
                ),
                Text(
                  'Đã nhận tháng này: ${income.irregular!.formattedReceivedThisMonth}',
                  style: AppTypography.caption(context),
                ),
              ],
              if (income.upcoming.isEmpty &&
                  income.late.isEmpty &&
                  income.irregular == null)
                Text(
                  'Chưa có dữ liệu thu nhập để dự báo.',
                  style: AppTypography.caption(context),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertsSection(
    BuildContext context,
    AsyncValue<List<ForecastAlertEntity>> async,
  ) {
    return _sectionCard(
      title: 'Cảnh báo dự báo',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.danger),
            ),
            TextButton(
              onPressed: () => ref.invalidate(forecastAlertsControllerProvider),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Text(
              'Chưa có cảnh báo nào.',
              style: AppTypography.caption(context),
            );
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
                          Expanded(
                            child: Text(
                              a.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _alertStatusLabel(a.status),
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                      Text(a.body, style: AppTypography.caption(context)),
                      Text(
                        '${_alertKindLabel(a.kind)} · ${_dayFormat.format(a.createdAt)}',
                        style: AppTypography.caption(
                          context,
                        ).copyWith(fontSize: 12),
                      ),
                      if (a.markedInaccurate)
                        Text(
                          'Đã báo không chính xác',
                          style: AppTypography.caption(
                            context,
                          ).copyWith(color: AppColors.warning),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: ValueKey('alert-mark-inaccurate-${a.id}'),
                            onPressed: () => ref
                                .read(forecastAlertsControllerProvider.notifier)
                                .markInaccurate(a.id),
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

  Widget _buildAnomaliesSection(
    BuildContext context,
    AsyncValue<List<AnomalyEntity>> async,
  ) {
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
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage(e),
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: AppColors.danger),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(anomaliesControllerProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
            data: (anomalies) {
              if (anomalies.isEmpty) {
                return Text(
                  _anomaliesOpenOnly
                      ? 'Không có khoản bất thường đang mở.'
                      : 'Chưa có khoản bất thường nào.',
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
                            Text(
                              _dayFormat.format(a.transactedAt!),
                              style: AppTypography.caption(
                                context,
                              ).copyWith(fontSize: 12),
                            ),
                          if (a.isResolved)
                            Text(
                              'Đã phản hồi: ${_anomalyResolutionLabel(a.resolution!)}',
                              style: AppTypography.caption(
                                context,
                              ).copyWith(color: AppColors.safe),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final r in const [
                                  'normal',
                                  'one_off',
                                  'wrong_entry',
                                  'suspicious',
                                ])
                                  AsyncActionBuilder(
                                    onPressed: () =>
                                        _sendAnomalyFeedback(a.id, r),
                                    builder: (_, onTap, running) =>
                                        OutlinedButton(
                                          key: ValueKey(
                                            'anomaly-feedback-$r-${a.id}',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                          onPressed: onTap,
                                          child: running
                                              ? const ButtonLoadingIndicator()
                                              : Text(
                                                  _anomalyResolutionLabel(r),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                        ),
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

  Widget _buildCategoriesSection(
    BuildContext context,
    AsyncValue<CategoryForecastEntity> async,
  ) {
    return _sectionCard(
      title: 'Dự báo chi tiêu theo danh mục',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.danger),
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(categoryForecastControllerProvider),
              child: const Text('Thử lại'),
            ),
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
                      onSelected: (_) => ref
                          .read(categoryForecastControllerProvider.notifier)
                          .setMonth(m),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!forecast.enoughHistory)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Chưa đủ dữ liệu lịch sử (mới có ${forecast.monthsWithData} tháng) — độ tin cậy thấp.',
                    style: AppTypography.caption(
                      context,
                    ).copyWith(color: AppColors.warning),
                  ),
                ),
              Text(
                'Tổng dự kiến: ${forecast.formattedProjectedTotal} (tháng trước: ${forecast.formattedPreviousMonthTotal})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (forecast.items.isEmpty)
                Text(
                  'Chưa có dữ liệu để dự báo.',
                  style: AppTypography.caption(context),
                )
              else
                for (final item in forecast.items)
                  Padding(
                    key: ValueKey(
                      'category-forecast-${item.categoryId ?? 'uncategorized'}',
                    ),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.categoryName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Dự kiến ${item.formattedProjected} (tháng trước ${item.formattedPreviousMonth}'
                          '${item.changePercent != null ? ', ${item.changePercent! > 0 ? '+' : ''}${item.changePercent}%' : ''})',
                          style: AppTypography.caption(context),
                        ),
                        Text(
                          '${_basisLabel(item.basis)} · Độ tin cậy: ${_confidenceLabel(item.confidence)}',
                          style: AppTypography.caption(
                            context,
                          ).copyWith(fontSize: 12),
                        ),
                        if (item.currentLimitCents != null)
                          Text(
                            'Ngân sách hiện tại: ${formatVnd(item.currentLimitCents!)}',
                            style: AppTypography.caption(context),
                          ),
                        if (item.suggestedLimitCents != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AsyncActionBuilder(
                              onPressed: _categoryApplyBusyId == item.categoryId
                                  ? null
                                  : () => _applySuggestedBudget(item),
                              builder: (_, onTap, running) => OutlinedButton(
                                key: ValueKey(
                                  'apply-category-budget-${item.categoryId}',
                                ),
                                onPressed: onTap,
                                child: running
                                    ? const ButtonLoadingIndicator()
                                    : Text(
                                        'Dùng ${formatVnd(item.suggestedLimitCents!)} làm ngân sách',
                                      ),
                              ),
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
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Text(
          errorMessage(e),
          style: AppTypography.caption(
            context,
          ).copyWith(color: AppColors.danger),
        ),
        data: (planning) {
          final goals = planning.savingsGoals;
          if (goals.isEmpty) {
            return Text(
              'Bạn chưa có mục tiêu tiết kiệm nào.',
              style: AppTypography.caption(context),
            );
          }
          final selectedId = goals.any((g) => g.id == _selectedGoalId)
              ? _selectedGoalId!
              : goals.first.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('goal-forecast-select'),
                initialValue: selectedId,
                decoration: const InputDecoration(labelText: 'Mục tiêu'),
                items: [
                  for (final g in goals)
                    DropdownMenuItem(value: g.id, child: Text(g.title)),
                ],
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
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errorMessage(e),
            style: AppTypography.caption(
              context,
            ).copyWith(color: AppColors.danger),
          ),
          TextButton(
            onPressed: () => ref.invalidate(goalForecastProvider(goalId)),
            child: const Text('Thử lại'),
          ),
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
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Đang xem theo mức góp giả định (chưa lưu)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            Text(
              'Đã để dành ${shown.formattedSaved} / ${shown.formattedTarget} (${shown.percentComplete}%) · ${_goalStatusLabel(shown.goalStatus)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${_forecastStatusLabel(shown.forecastStatus)} · Độ tin cậy: ${_confidenceLabel(shown.confidence)}',
              style: AppTypography.caption(
                context,
              ).copyWith(color: _forecastStatusColor(shown.forecastStatus)),
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
                AsyncActionBuilder(
                  onPressed: _goalScenarioBusy
                      ? null
                      : () => _openGoalScenario(goalId),
                  builder: (_, onTap, running) => TextButton.icon(
                    key: const ValueKey('goal-scenario-button'),
                    onPressed: onTap,
                    icon: running
                        ? const ButtonLoadingIndicator(size: 16)
                        : const Icon(LucideIcons.plusCircle, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Thử mức góp khác', maxLines: 1),
                    ),
                  ),
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
      style: AppTypography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w600),
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
    final amountValue = BigInt.tryParse(
      _amount.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    // BE bắt buộc mỗi khoản giả định phải có tên (1-60 ký tự), không chấp nhận rỗng.
    final valid =
        amountValue != null &&
        amountValue > BigInt.zero &&
        _label.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Thử kịch bản'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<RecurringDirection>(
              segments: const [
                ButtonSegment(
                  value: RecurringDirection.inflow,
                  label: Text('Khoản thu'),
                ),
                ButtonSegment(
                  value: RecurringDirection.outflow,
                  label: Text('Khoản chi'),
                ),
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
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_date),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
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
    final amountValue = BigInt.tryParse(
      _amount.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          key: const ValueKey('confirm-goal-scenario'),
          onPressed: !valid ? null : () => Navigator.pop(context, amountValue),
          child: const Text('Xem kết quả'),
        ),
      ],
    );
  }
}

/// Thẻ "Số tiền có thể chi" dạng trực quan: con số lớn, thác nước cách tính, thanh chia theo ví.
/// Mọi số lấy nguyên từ `GET /forecast/spendable`; FE chỉ cộng dồn các bước BE đã trả để vẽ thác nước.
class _SpendableView extends StatelessWidget {
  const _SpendableView({
    required this.spendable,
    required this.basisLabel,
    required this.dayFormat,
  });

  final SafeToSpendEntity spendable;
  final String basisLabel;
  final DateFormat dayFormat;

  @override
  Widget build(BuildContext context) {
    final s = spendable;
    final short = s.hasShortfall;
    final caption = AppTypography.caption(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$basisLabel · ${dayFormat.format(s.periodStart)} - ${dayFormat.format(s.periodEnd)} (còn ${s.daysRemaining} ngày)',
          style: caption,
        ),
        const SizedBox(height: 10),
        Text(
          short ? 'Thiếu' : 'Có thể chi',
          style: caption.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          short ? s.formattedShortfall : s.formattedSpendable,
          key: const ValueKey('spendable-amount'),
          style: AppTypography.tabular(
            AppTypography.h1(context).copyWith(
              fontSize: 30,
              color: short ? AppColors.danger : AppColors.safe,
            ),
          ),
        ),
        if (!short)
          Text(
            'Khoảng ${s.formattedPerDay}/ngày',
            key: const ValueKey('spendable-per-day'),
            style: caption,
          ),
        const SizedBox(height: 16),
        _Waterfall(spendable: s),
        if (s.accounts.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Theo ví', style: caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _WalletBar(accounts: s.accounts),
        ],
        if (s.bills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Hóa đơn sắp tới',
            style: caption.copyWith(fontWeight: FontWeight.w700),
          ),
          for (final b in s.bills)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dayFormat.format(b.date)} · ${b.label}',
                      style: caption,
                    ),
                  ),
                  Text(
                    b.formattedAmount,
                    style: AppTypography.tabular(
                      caption.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (s.goals.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Mục tiêu tiết kiệm',
            style: caption.copyWith(fontWeight: FontWeight.w700),
          ),
          // Mục tiêu đang để dành tiền hiện từng dòng; mục tiêu 0 ₫ gộp lại cho gọn
          for (final g in s.goals.where((g) => g.setAsideCents > BigInt.zero))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${g.name}: để dành ${g.formattedSetAside}',
                style: caption,
              ),
            ),
          if (s.goals.any((g) => g.setAsideCents <= BigInt.zero))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${s.goals.where((g) => g.setAsideCents <= BigInt.zero).length} mục tiêu chưa để dành trong kỳ này',
                style: caption.copyWith(color: AppColors.textMuted(context)),
              ),
            ),
        ],
      ],
    );
  }
}

/// Một bước trong thác nước: nhãn, số tiền (dương = cộng, âm = trừ)
class _Step {
  const _Step(this.label, this.deltaCents, this.color);
  final String label;
  final BigInt deltaCents;
  final Color color;
}

/// Biểu đồ thác nước ngang: mỗi bước là một thanh bắt đầu từ tổng trước đó, dòng cuối là kết quả.
/// Các bước bằng 0 bị ẩn.
class _Waterfall extends StatelessWidget {
  const _Waterfall({required this.spendable});
  final SafeToSpendEntity spendable;

  @override
  Widget build(BuildContext context) {
    final s = spendable;
    final steps = <_Step>[
      _Step('Số dư hiện có', s.balanceCents, AppColors.slateOn(context)),
      _Step('Thu nhập dự kiến', s.expectedIncomeCents, AppColors.safe),
      _Step('Hóa đơn sắp tới', -s.upcomingBillsCents, AppColors.danger),
      _Step('Dành cho mục tiêu', -s.goalSetAsideCents, AppColors.danger),
      _Step('Khoản dự phòng', -s.reserveCents, AppColors.danger),
    ].where((st) => st.deltaCents != BigInt.zero).toList();

    // Thang vẽ: từ min(0, các mốc) tới max các mốc cộng dồn
    var running = BigInt.zero;
    var hi = BigInt.zero;
    var lo = BigInt.zero;
    final spans = <(BigInt, BigInt)>[];
    for (final st in steps) {
      final next = running + st.deltaCents;
      spans.add((running, next));
      running = next;
      if (running > hi) hi = running;
      if (running < lo) lo = running;
    }
    final total = s.hasShortfall ? -s.shortfallCents : s.spendableCents;
    final range = (hi - lo) == BigInt.zero ? BigInt.one : hi - lo;
    double pos(BigInt v) => (v - lo).toDouble() / range.toDouble();

    final caption = AppTypography.caption(context);
    Widget row(
      String label,
      BigInt from,
      BigInt to,
      Color color,
      String value, {
      bool strong = false,
    }) {
      final a = pos(from < to ? from : to);
      final b = pos(from < to ? to : from);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: caption.copyWith(
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                      color: strong ? AppColors.textPrimary(context) : null,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.tabular(
                    caption.copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, c) => SizedBox(
                height: strong ? 12 : 8,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.inset(context, 0.5),
                          borderRadius: AppSpacing.roundedPill,
                        ),
                      ),
                    ),
                    Positioned(
                      left: c.maxWidth * a,
                      width: (c.maxWidth * (b - a)).clamp(4.0, c.maxWidth),
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    String signed(BigInt v) =>
        '${v < BigInt.zero ? '-' : '+'}${formatVnd(v.abs())}';
    return Semantics(
      label: 'Cách tính số tiền có thể chi',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            row(
              steps[i].label,
              spans[i].$1,
              spans[i].$2,
              steps[i].color,
              i == 0
                  ? formatVnd(steps[i].deltaCents)
                  : signed(steps[i].deltaCents),
            ),
          Divider(height: 8, color: AppColors.glassBorder(context)),
          const SizedBox(height: 6),
          row(
            s.hasShortfall ? 'Còn thiếu' : 'Có thể chi',
            BigInt.zero > lo ? BigInt.zero : lo,
            total,
            s.hasShortfall ? AppColors.danger : AppColors.safe,
            s.hasShortfall ? s.formattedShortfall : s.formattedSpendable,
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// Thanh ngang chia theo ví: mỗi ví dương một đoạn theo tỉ lệ; ví âm báo đỏ riêng; ví 0 ₫ gộp một dòng.
class _WalletBar extends StatelessWidget {
  const _WalletBar({required this.accounts});
  final List<SpendableAccountEntity> accounts;

  @override
  Widget build(BuildContext context) {
    final positive =
        accounts.where((a) => a.balanceCents > BigInt.zero).toList()
          ..sort((a, b) => b.balanceCents.compareTo(a.balanceCents));
    final negative = accounts
        .where((a) => a.balanceCents < BigInt.zero)
        .toList();
    final zero = accounts.where((a) => a.balanceCents == BigInt.zero).length;
    final palette = AppColors.activeChartPalette(context);
    final sum = positive.fold<BigInt>(
      BigInt.zero,
      (s, a) => s + a.balanceCents,
    );
    final caption = AppTypography.caption(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (positive.isNotEmpty)
          ClipRRect(
            borderRadius: AppSpacing.roundedPill,
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < positive.length; i++)
                    Expanded(
                      // flex tối thiểu 1 để ví nhỏ vẫn thấy được
                      flex:
                          ((positive[i].balanceCents * BigInt.from(1000)) ~/
                                  sum)
                              .toInt()
                              .clamp(1, 1000),
                      child: ColoredBox(color: palette[i % palette.length]),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < positive.length; i++)
          _legend(
            context,
            palette[i % palette.length],
            positive[i].name,
            positive[i].formattedBalance,
          ),
        for (final a in negative)
          _legend(
            context,
            AppColors.danger,
            '${a.name} (âm)',
            a.formattedBalance,
            valueColor: AppColors.danger,
          ),
        if (zero > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$zero ví khác: 0 ₫',
              style: caption.copyWith(color: AppColors.textMuted(context)),
            ),
          ),
      ],
    );
  }

  Widget _legend(
    BuildContext context,
    Color color,
    String name,
    String value, {
    Color? valueColor,
  }) {
    final caption = AppTypography.caption(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: caption,
            ),
          ),
          Text(
            value,
            style: AppTypography.tabular(
              caption.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
