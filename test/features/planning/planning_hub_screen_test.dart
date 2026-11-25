import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/planning/presentation/screens/planning_hub_screen.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';

class _FakePlanning extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  _FakePlanning(super.state);

  @override
  Future<void> loadPlanningData({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecurring extends StateNotifier<AsyncValue<List<RecurringItemEntity>>> implements RecurringItemsController {
  _FakeRecurring(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BudgetEntity _budget({String? categoryId, String category = 'Tổng thể', int limit = 10000000, int spent = 0}) => BudgetEntity(
      id: 'b-$category',
      categoryId: categoryId,
      category: category,
      limitAmountCents: BigInt.from(limit),
      spentAmountCents: BigInt.from(spent),
      month: 11,
      year: 2026,
    );

Future<List<String>> _pump(
  WidgetTester tester, {
  required AsyncValue<PlanningState> planning,
  List<RecurringItemEntity> recurring = const [],
  Size size = const Size(360, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PlanningHubScreen()),
      for (final p in ['/planning/goals', '/planning/budgets', '/planning/budgets/form', '/planning/recurring', '/planning/loans'])
        GoRoute(
          path: p,
          builder: (_, __) {
            pushed.add(p);
            return Scaffold(appBar: AppBar(), body: Text('route:$p'));
          },
        ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      planningControllerProvider.overrideWith((ref) => _FakePlanning(planning)),
      recurringItemsControllerProvider.overrideWith((ref) => _FakeRecurring(AsyncValue.data(recurring))),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  group('PlanningHubScreen (G1)', () {
    testWidgets('có ngân sách tổng: hiện hạn mức theo ngày và đủ 4 trụ cột, không tràn ngang ở 360dp', (tester) async {
      await _pump(
        tester,
        planning: AsyncValue.data(PlanningState(
          overallBudget: _budget(limit: 22000000, spent: 18250000),
          categoryBudgets: const [],
          savingsGoals: const [],
          daysRemainingInMonth: 10,
        )),
      );

      expect(find.text('HẠN MỨC THEO NGÀY'), findsOneWidget);
      expect(find.text('Chi an toàn hôm nay'), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-pillar-goals')), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-pillar-budgets')), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-pillar-recurring')), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-pillar-loans')), findsOneWidget);
      // 83% đã dùng: cảnh báo sắp chạm ngưỡng, không hiện số liệu bịa cho khoản vay
      expect(find.text('Sắp chạm ngưỡng'), findsOneWidget);
    });

    testWidgets('chưa có ngân sách tổng: mời tạo, không hiện "0 ₫"', (tester) async {
      final pushed = await _pump(
        tester,
        planning: const AsyncValue.data(PlanningState(
          overallBudget: null,
          categoryBudgets: [],
          savingsGoals: [],
          daysRemainingInMonth: 10,
        )),
      );

      expect(find.text('Chi an toàn hôm nay'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('hub-create-total-budget')));
      await tester.pumpAndSettle();
      expect(pushed, contains('/planning/budgets/form'));
    });

    testWidgets('bấm từng trụ cột mở đúng màn', (tester) async {
      final pushed = await _pump(
        tester,
        planning: AsyncValue.data(PlanningState(
          overallBudget: _budget(limit: 1000000, spent: 100000),
          categoryBudgets: const [],
          savingsGoals: <SavingsGoalEntity>[],
          daysRemainingInMonth: 10,
        )),
      );

      for (final entry in {
        'hub-pillar-goals': '/planning/goals',
        'hub-pillar-budgets': '/planning/budgets',
        'hub-pillar-recurring': '/planning/recurring',
        'hub-pillar-loans': '/planning/loans',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
        await tester.tap(find.byKey(ValueKey(entry.key)));
        await tester.pumpAndSettle();
        expect(pushed.last, entry.value);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('lỗi tải: hiện thông điệp và nút Thử lại', (tester) async {
      await _pump(tester, planning: AsyncValue.error(Exception('boom'), StackTrace.empty));
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
