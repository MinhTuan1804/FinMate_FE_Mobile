import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/planning/presentation/screens/planning_screen.dart';
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

  group('PlanningScreen', () {
    Future<MockPlanningController> pump(WidgetTester tester, AsyncValue<PlanningState> state) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mock = MockPlanningController(state);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          planningControllerProvider.overrideWith((ref) => mock),
          categoriesProvider.overrideWith((ref) async => (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList()),
        ],
        child: const MaterialApp(home: PlanningScreen()),
      ));
      await tester.pumpAndSettle();
      return mock;
    }

    PlanningState stateWith({BudgetEntity? overall, List<SavingsGoalEntity> goals = const [], List<BudgetEntity> categoryBudgets = const []}) => PlanningState(
          overallBudget: overall,
          categoryBudgets: categoryBudgets,
          savingsGoals: goals,
          daysRemainingInMonth: 10,
        );

    testWidgets('có ngân sách tổng: hiện hạn mức chi tiêu hôm nay', (tester) async {
      await pump(tester, AsyncValue.data(stateWith(overall: _budget(limit: 15000000, spent: 9000000))));

      expect(find.text('Kế hoạch tài chính'), findsOneWidget);
      expect(find.text('HẠN MỨC CHI TIÊU HÔM NAY'), findsOneWidget);
      expect(find.text('600.000 ₫ / ngày'), findsOneWidget);
      expect(find.text('NGÂN SÁCH THEO DANH MỤC'), findsOneWidget);
    });

    testWidgets('chưa có ngân sách tổng: mời tạo, không hiện "0 ₫ / ngày"', (tester) async {
      await pump(tester, AsyncValue.data(stateWith()));

      expect(find.text('Bạn chưa đặt ngân sách tháng này'), findsOneWidget);
      expect(find.text('Tạo ngân sách tháng'), findsOneWidget);
      expect(find.textContaining('/ ngày'), findsNothing);
    });

    testWidgets('lỗi tải: hiện thông điệp thân thiện và nút Thử lại', (tester) async {
      await pump(tester, AsyncValue.error(Exception('Không có kết nối mạng'), StackTrace.empty));

      expect(find.text('Không có kết nối mạng'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('nạp tiền mục tiêu: nhập số tiền, gọi controller và báo đã nạp', (tester) async {
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [_goal(deadline: DateTime(2027, 1, 1))])));
      mock.nextResult = _goal(current: 2000000);

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nạp tiền vào mục tiêu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1.000.000');
      await tester.tap(find.text('Nạp tiền'));
      await tester.pumpAndSettle();

      expect(mock.contributions.single.$1, 'g1');
      expect(mock.contributions.single.$2, BigInt.from(1000000));
      expect(find.text('Đã nạp 1.000.000 ₫ vào mục tiêu!'), findsOneWidget);
      expect(find.textContaining('lên cấp'), findsNothing);
    });

    testWidgets('nạp tiền với số 0 bị chặn, không gọi controller', (tester) async {
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [_goal()])));

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nạp tiền vào mục tiêu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Nạp tiền'));
      await tester.pumpAndSettle();

      expect(mock.contributions, isEmpty);
      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
    });

    testWidgets('xoá ngân sách theo danh mục: xác nhận rồi gọi controller', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final mock = await pump(tester, AsyncValue.data(stateWith(categoryBudgets: [budget])));

      await tester.tap(find.byKey(ValueKey('delete-budget-${budget.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Xoá ngân sách'), findsOneWidget);

      await tester.tap(find.text('Xoá'));
      await tester.pumpAndSettle();

      expect(mock.deletedBudgetIds, [budget.id]);
      expect(find.text('Đã xoá ngân sách'), findsOneWidget);
    });

    testWidgets('hủy xoá ngân sách: không gọi controller', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final mock = await pump(tester, AsyncValue.data(stateWith(categoryBudgets: [budget])));

      await tester.tap(find.byKey(ValueKey('delete-budget-${budget.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(mock.deletedBudgetIds, isEmpty);
    });

    testWidgets('chỉ 1 ngân sách danh mục: không hiện nút "Chuyển"', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      await pump(tester, AsyncValue.data(stateWith(categoryBudgets: [budget])));

      expect(find.text('Chuyển'), findsNothing);
    });

    testWidgets('chuyển hạn mức giữa 2 ngân sách danh mục: chọn nguồn/đích, nhập số tiền, gọi controller', (tester) async {
      final food = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final transport = _budget(categoryId: 'cat-2', category: 'Di chuyển', limit: 2000000, spent: 500000);
      final mock = await pump(tester, AsyncValue.data(stateWith(categoryBudgets: [food, transport])));

      await tester.tap(find.text('Chuyển'));
      await tester.pumpAndSettle();
      expect(find.text('Chuyển hạn mức'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Di chuyển').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '500.000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Chuyển'));
      await tester.pumpAndSettle();

      expect(mock.transfers.single, (food.id, transport.id, BigInt.from(500000)));
      expect(find.text('Đã chuyển hạn mức'), findsOneWidget);
    });

    testWidgets('chuyển hạn mức: chọn cùng 1 danh mục cho nguồn và đích thì bị chặn', (tester) async {
      final food = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final transport = _budget(categoryId: 'cat-2', category: 'Di chuyển', limit: 2000000, spent: 500000);
      final mock = await pump(tester, AsyncValue.data(stateWith(categoryBudgets: [food, transport])));

      await tester.tap(find.text('Chuyển'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '500.000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Chuyển'));
      await tester.pumpAndSettle();

      expect(mock.transfers, isEmpty);
      expect(find.text('Danh mục nguồn và đích phải khác nhau'), findsOneWidget);
    });

    testWidgets('sửa mục tiêu: đổi tên, gọi controller.updateGoal', (tester) async {
      final goal = _goal(deadline: DateTime(2027, 1, 1));
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [goal])));

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('edit-goal-${goal.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Sửa mục tiêu'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Tên mục tiêu (ví dụ: Quỹ du lịch)'), 'Quỹ khẩn cấp (mới)');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(mock.goalUpdates.single.id, goal.id);
      expect(mock.goalUpdates.single.name, 'Quỹ khẩn cấp (mới)');
      expect(find.text('Đã lưu mục tiêu'), findsOneWidget);
    });

    testWidgets('hủy mục tiêu đang active: xác nhận rồi gọi controller.cancelGoal', (tester) async {
      final goal = _goal(status: 'active');
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [goal])));

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('cancel-goal-${goal.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Hủy mục tiêu'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Hủy mục tiêu'));
      await tester.pumpAndSettle();

      expect(mock.cancelledGoalIds, [goal.id]);
      expect(find.text('Đã hủy mục tiêu'), findsOneWidget);
    });

    testWidgets('mục tiêu đã hoàn thành: không hiện nút hủy', (tester) async {
      final goal = _goal(status: 'completed', current: 45000000, target: 45000000);
      await pump(tester, AsyncValue.data(stateWith(goals: [goal])));

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('cancel-goal-${goal.id}')), findsNothing);
    });

    testWidgets('xem tiến độ mục tiêu: hiện số ngày còn lại, cần nạp/ngày và tính khả thi', (tester) async {
      final goal = _goal();
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [goal])));
      mock.nextProgress = GoalProgressEntity(
        goalId: 'g1',
        name: 'Quỹ khẩn cấp',
        status: 'active',
        targetCents: BigInt.from(45000000),
        savedCents: BigInt.from(1000000),
        remainingCents: BigInt.from(44000000),
        percentComplete: 2,
        daysRemaining: 55,
        requiredPerDayCents: BigInt.from(800000),
        isOnTrack: true,
        feasibility: GoalFeasibilityEntity(requiredPerMonthCents: BigInt.from(22000000), isFeasible: false),
      );

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('goal-detail-${goal.id}')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Còn 55 ngày'), findsOneWidget);
      expect(find.textContaining('vượt khả năng tài chính hiện tại'), findsOneWidget);
    });

    testWidgets('sửa mục tiêu: xem trước tính khả thi (đã có hạn chót sẵn) gọi controller.previewFeasibility và hiện kết quả', (tester) async {
      final goal = _goal(deadline: DateTime(2027, 1, 1));
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [goal])));
      mock.nextFeasibility = GoalFeasibilityEntity(requiredPerMonthCents: BigInt.from(5000000), isFeasible: true);

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('edit-goal-${goal.id}')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xem trước tính khả thi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cần ~5.000.000'), findsOneWidget);
    });

    testWidgets('xem trước tính khả thi: thiếu hạn chót thì báo lỗi, không gọi controller', (tester) async {
      final goal = _goal(deadline: null);
      final mock = await pump(tester, AsyncValue.data(stateWith(goals: [goal])));

      await tester.tap(find.text('Mục tiêu tiết kiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('edit-goal-${goal.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem trước tính khả thi'));
      await tester.pumpAndSettle();

      expect(mock.previewFeasibilityCalls, 0);
      expect(find.text('Vui lòng chọn hạn chót để xem khả thi'), findsOneWidget);
    });
  });
}
