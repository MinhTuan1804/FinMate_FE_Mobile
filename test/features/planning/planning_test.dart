import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import '../../fixtures/fixture.dart';

class MockPlanningController extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  final List<(String, BigInt)> contributions = [];
  final List<String> deletedBudgetIds = [];
  final List<(String, String, BigInt)> transfers = [];
  final List<({String id, String name, BigInt target, DateTime? deadline})> goalUpdates = [];
  final List<String> cancelledGoalIds = [];
  SavingsGoalEntity? nextResult;
  GoalProgressEntity? nextProgress;
  GoalFeasibilityEntity? nextFeasibility;

  MockPlanningController(super.state);

  @override
  Future<SavingsGoalEntity> contributeToGoal(String goalId, BigInt amountCents) async {
    contributions.add((goalId, amountCents));
    return nextResult!;
  }

  @override
  Future<void> deleteBudget(String id) async {
    deletedBudgetIds.add(id);
  }

  @override
  Future<void> transferBudgetLimit({required String fromBudgetId, required String toBudgetId, required BigInt amountCents}) async {
    transfers.add((fromBudgetId, toBudgetId, amountCents));
  }

  @override
  Future<void> updateGoal({required String id, required String name, required BigInt targetCents, DateTime? deadline}) async {
    goalUpdates.add((id: id, name: name, target: targetCents, deadline: deadline));
  }

  @override
  Future<void> cancelGoal(String id) async {
    cancelledGoalIds.add(id);
  }

  @override
  Future<GoalProgressEntity> getGoalProgress(String id) async => nextProgress!;

  int previewFeasibilityCalls = 0;

  @override
  Future<GoalFeasibilityEntity?> previewFeasibility({required BigInt targetCents, BigInt? savedCents, required DateTime deadline}) async {
    previewFeasibilityCalls++;
    return nextFeasibility;
  }

  @override
  Future<void> loadPlanningData({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BudgetEntity _budget({String? categoryId, String category = 'Tổng thể', int limit = 10000000, int spent = 0}) => BudgetEntity(
      id: 'b-$category',
      categoryId: categoryId,
      category: category,
      limitAmountCents: BigInt.from(limit),
      spentAmountCents: BigInt.from(spent),
      month: 10,
      year: 2026,
    );

SavingsGoalEntity _goal({String status = 'active', int target = 45000000, int current = 1000000, DateTime? deadline}) => SavingsGoalEntity(
      id: 'g1',
      title: 'Quỹ khẩn cấp',
      targetAmountCents: BigInt.from(target),
      currentAmountCents: BigInt.from(current),
      targetDate: deadline,
      status: status,
    );

void main() {
  group('BudgetEntity', () {
    test('BR-43: 3 dải màu Xanh (<70%), Vàng (70-89%), Đỏ (>=90%)', () {
      final safe = _budget(category: 'Ăn uống', limit: 5000000, spent: 3000000);
      expect(safe.spendingPercentage, 60.0);
      expect(safe.statusColor, AppColors.safe);
      expect(safe.statusLevel, BudgetStatusLevel.safe);

      final warning = _budget(category: 'Mua sắm', limit: 4000000, spent: 3200000);
      expect(warning.spendingPercentage, 80.0);
      expect(warning.statusLevel, BudgetStatusLevel.warning);

      final danger = _budget(category: 'Giải trí', limit: 2000000, spent: 1900000);
      expect(danger.spendingPercentage, 95.0);
      expect(danger.statusColor, AppColors.danger);
    });

    test('BR-50: hạn mức chi tiêu an toàn mỗi ngày; vượt ngân sách thì bằng 0', () {
      final budget = _budget(limit: 10000000, spent: 7000000);
      expect(budget.dailySafeSpendingLimit(daysRemaining: 10), BigInt.from(300000));

      final over = _budget(limit: 10000000, spent: 11000000);
      expect(over.dailySafeSpendingLimit(daysRemaining: 10), BigInt.zero);
      expect(over.isOverspent, true);
    });

    test('limit bằng 0 không chia cho 0', () {
      expect(_budget(limit: 0, spent: 100).spendingPercentage, 0.0);
    });

    test('fromJson đọc budgets.json thật (ngân sách tổng và theo danh mục)', () {
      final data = fixtureData('budgets') as Map<String, dynamic>;

      final total = BudgetEntity.fromJson(data['totalBudget'] as Map<String, dynamic>, month: 9, year: 2026);
      expect(total.categoryId, isNull);
      expect(total.category, 'Tổng thể');
      expect(total.limitAmountCents, BigInt.from(15000000));
      expect(total.spentAmountCents, BigInt.from(45000));

      final food = BudgetEntity.fromJson((data['categoryBudgets'] as List).first as Map<String, dynamic>, month: 9, year: 2026);
      expect(food.category, 'Ăn uống');
      expect(food.categoryId, isNotNull);
    });
  });

  group('SavingsGoalEntity', () {
    final asOf = DateTime(2026, 9, 30);

    test('fromJson đọc saving_goals.json thật', () {
      final goal = SavingsGoalEntity.fromJson((fixtureData('saving_goals') as List).first as Map<String, dynamic>);

      expect(goal.targetAmountCents, BigInt.from(45000000));
      expect(goal.currentAmountCents, BigInt.from(1000000));
      expect(goal.targetDate, isNotNull);
      expect(goal.status, 'active');
      expect(goal.progressPercentage, 2.2);
    });

    test('không có hạn chót: không crash, không tính số tiền cần nạp mỗi tháng', () {
      final goal = SavingsGoalEntity.fromJson({
        'id': 'g',
        'name': 'Không hạn',
        'targetCents': 1000,
        'savedCents': 0,
        'status': 'active',
        'deadline': null,
      });

      expect(goal.targetDate, isNull);
      expect(goal.requiredPerMonth(asOf: asOf), isNull);
      expect(goal.statusLabel(asOf: asOf), 'Không hạn chót');
    });

    test('số tiền cần nạp mỗi tháng = phần còn thiếu / số tháng còn lại (làm tròn lên)', () {
      final goal = _goal(target: 30000000, current: 12000000, deadline: DateTime(2026, 12, 31)); // còn 3 tháng
      expect(goal.requiredPerMonth(asOf: asOf), BigInt.from(6000000));
      expect(goal.statusLabel(asOf: asOf), 'Cần ~6.000.000 ₫/tháng');
    });

    test('hạn chót trong cùng tháng: tối thiểu 1 tháng', () {
      final goal = _goal(target: 1000, current: 0, deadline: DateTime(2026, 9, 30, 23));
      expect(goal.requiredPerMonth(asOf: asOf), BigInt.from(1000));
    });

    test('hoàn thành và trễ hạn', () {
      expect(_goal(status: 'completed').statusLabel(asOf: asOf), 'Hoàn thành');
      expect(_goal(current: 45000000).isCompleted, isTrue);
      final late = _goal(deadline: DateTime(2026, 8, 1));
      expect(late.isOverdue(asOf: asOf), isTrue);
      expect(late.statusLabel(asOf: asOf), 'Trễ hạn');
      expect(late.requiredPerMonth(asOf: asOf), isNull);
    });
  });

  group('PlanningState', () {
    test('dailySafeLimit lấy từ ngân sách tổng; không có ngân sách tổng thì bằng 0', () {
      final withTotal = PlanningState(
        overallBudget: _budget(limit: 15000000, spent: 9000000),
        categoryBudgets: const [],
        savingsGoals: const [],
        daysRemainingInMonth: 10,
      );
      expect(withTotal.dailySafeLimit, BigInt.from(600000));

      final without = PlanningState(overallBudget: null, categoryBudgets: const [], savingsGoals: const [], daysRemainingInMonth: 10);
      expect(without.dailySafeLimit, BigInt.zero);
    });
  });
}
