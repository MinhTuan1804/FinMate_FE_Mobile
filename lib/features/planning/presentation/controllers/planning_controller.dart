import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/data/planning_repository.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';

class PlanningState {
  /// Ngân sách tổng của tháng; null nếu người dùng chưa đặt
  final BudgetEntity? overallBudget;
  final List<BudgetEntity> categoryBudgets;
  final List<SavingsGoalEntity> savingsGoals;
  final int daysRemainingInMonth;

  const PlanningState({
    required this.overallBudget,
    required this.categoryBudgets,
    required this.savingsGoals,
    required this.daysRemainingInMonth,
  });

  BigInt get dailySafeLimit {
    final overall = overallBudget;
    if (overall == null) return BigInt.zero;
    return overall.dailySafeSpendingLimit(daysRemaining: daysRemainingInMonth);
  }
}

/// Tạo lại (và tải lại) khi đổi người dùng; chưa đăng nhập thì không gọi API
final planningControllerProvider = StateNotifierProvider<PlanningController, AsyncValue<PlanningState>>((ref) {
  final signedIn = ref.watch(currentUserIdProvider) != null;
  return PlanningController(
    repository: ref.watch(planningRepositoryProvider),
    enabled: signedIn,
  );
});

class PlanningController extends StateNotifier<AsyncValue<PlanningState>> {
  final PlanningRepository repository;

  PlanningController({required this.repository, bool enabled = true})
      : super(const AsyncValue.loading()) {
    if (enabled) {
      loadPlanningData();
    } else {
      state = AsyncValue.data(const PlanningState(overallBudget: null, categoryBudgets: [], savingsGoals: [], daysRemainingInMonth: 1));
    }
  }

  int _calculateDaysRemaining() {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final remaining = lastDayOfMonth - now.day;
    return remaining > 0 ? remaining : 1;
  }

  /// [silent]: giữ nguyên dữ liệu đang hiển thị trong lúc tải lại (dùng sau khi tạo/sửa)
  Future<void> loadPlanningData({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final budgets = await repository.getBudgets(month: now.month, year: now.year);
      final goals = await repository.getGoals();
      if (!mounted) return;
      state = AsyncValue.data(
        PlanningState(
          overallBudget: budgets.total,
          categoryBudgets: budgets.categories,
          savingsGoals: goals,
          daysRemainingInMonth: _calculateDaysRemaining(),
        ),
      );
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Tạo ngân sách (categoryId null = ngân sách tổng) hoặc sửa hạn mức nếu đã tồn tại. Lỗi được ném lại.
  Future<void> createOrUpdateBudget({String? categoryId, required BigInt limitAmountCents}) async {
    final current = state.valueOrNull;
    final existing = categoryId == null
        ? current?.overallBudget
        : current?.categoryBudgets.where((b) => b.categoryId == categoryId).firstOrNull;

    if (existing != null) {
      await repository.updateBudgetLimit(existing.id, limitAmountCents);
    } else {
      await repository.createBudget(categoryId: categoryId, limitCents: limitAmountCents);
    }
    await loadPlanningData(silent: true);
  }

  Future<void> createSavingsGoal({
    required String title,
    required BigInt targetAmountCents,
    DateTime? targetDate,
  }) async {
    await repository.createGoal(name: title, targetCents: targetAmountCents, deadline: targetDate);
    await loadPlanningData(silent: true);
  }

  Future<SavingsGoalEntity> contributeToGoal(String goalId, BigInt amountCents) async {
    final result = await repository.contribute(goalId, amountCents);
    await loadPlanningData(silent: true);
    return result;
  }
}
