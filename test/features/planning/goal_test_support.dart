import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/planning/presentation/screens/goal_form_screen.dart';
import 'package:finmate/features/planning/presentation/screens/savings_goal_detail_screen.dart';

class MockGoalController extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  final List<(String, BigInt)> contributions = [];
  final List<({String id, String name, BigInt target, DateTime? deadline})> goalUpdates = [];
  final List<({String title, BigInt target, DateTime? deadline})> goalCreates = [];
  final List<String> cancelledGoalIds = [];
  SavingsGoalEntity? nextResult;
  GoalProgressEntity? nextProgress;
  GoalFeasibilityEntity? nextFeasibility;
  int previewFeasibilityCalls = 0;

  MockGoalController(super.state);

  @override
  Future<SavingsGoalEntity> contributeToGoal(String goalId, BigInt amountCents) async {
    contributions.add((goalId, amountCents));
    return nextResult!;
  }

  @override
  Future<String?> createSavingsGoal({required String title, required BigInt targetAmountCents, DateTime? targetDate}) async {
    goalCreates.add((title: title, target: targetAmountCents, deadline: targetDate));
    return null;
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

SavingsGoalEntity testGoal({
  String id = 'g1',
  String title = 'Quỹ khẩn cấp',
  String status = 'active',
  int target = 45000000,
  int current = 1000000,
  DateTime? deadline,
}) => SavingsGoalEntity(
  id: id,
  title: title,
  targetAmountCents: BigInt.from(target),
  currentAmountCents: BigInt.from(current),
  targetDate: deadline,
  status: status,
);

PlanningState planningWith(List<SavingsGoalEntity> goals) =>
    PlanningState(overallBudget: null, categoryBudgets: const [], savingsGoals: goals, daysRemainingInMonth: 10);

/// Bơm [home] trong GoRouter có sẵn route chi tiết/form để `context.push` chạy được; viewport 360dp.
/// [prepare] chạy trước lần dựng đầu để đặt sẵn dữ liệu cho mock.
Future<MockGoalController> pumpGoalApp(
  WidgetTester tester, {
  required Widget home,
  required AsyncValue<PlanningState> state,
  void Function(MockGoalController mock)? prepare,
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final mock = MockGoalController(state);
  prepare?.call(mock);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/planning/goal', builder: (_, s) => SavingsGoalDetailScreen(goal: s.extra as SavingsGoalEntity)),
      GoRoute(path: '/planning/goals/form', builder: (_, s) => GoalFormScreen(goal: s.extra as SavingsGoalEntity?)),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [planningControllerProvider.overrideWith((ref) => mock)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return mock;
}
