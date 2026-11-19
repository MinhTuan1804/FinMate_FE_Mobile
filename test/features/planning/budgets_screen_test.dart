import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/planning/presentation/screens/budgets_screen.dart';
import '../../fixtures/fixture.dart';

class MockPlanningController extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  final List<String> deletedBudgetIds = [];
  final List<(String, String, BigInt)> transfers = [];

  MockPlanningController(super.state);

  @override
  Future<void> deleteBudget(String id) async {
    deletedBudgetIds.add(id);
  }

  @override
  Future<void> transferBudgetLimit({required String fromBudgetId, required String toBudgetId, required BigInt amountCents}) async {
    transfers.add((fromBudgetId, toBudgetId, amountCents));
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

PlanningState _stateWith({BudgetEntity? overall, List<BudgetEntity> categoryBudgets = const []}) => PlanningState(
      overallBudget: overall,
      categoryBudgets: categoryBudgets,
      savingsGoals: const [],
      daysRemainingInMonth: 10,
    );

void main() {
  group('BudgetsScreen (G5)', () {
    final pushed = <Object?>[];

    Future<MockPlanningController> pump(WidgetTester tester, AsyncValue<PlanningState> state, {double width = 800}) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      pushed.clear();
      final mock = MockPlanningController(state);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const BudgetsScreen()),
        GoRoute(
          path: '/planning/budgets/form',
          builder: (_, s) {
            pushed.add(s.extra);
            return Scaffold(appBar: AppBar(), body: const Text('form'));
          },
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          planningControllerProvider.overrideWith((ref) => mock),
          categoriesProvider.overrideWith((ref) async => (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return mock;
    }

    testWidgets('có ngân sách tổng: hiện hạn mức, đã chi và chi an toàn hôm nay', (tester) async {
      await pump(tester, AsyncValue.data(_stateWith(overall: _budget(limit: 15000000, spent: 9000000))));

      expect(find.text('Ngân sách chi tiêu'), findsOneWidget);
      expect(find.text('15.000.000 ₫'), findsOneWidget);
      expect(find.text('60% đã dùng'), findsOneWidget);
      expect(find.text('600.000 ₫ / ngày'), findsOneWidget);
      expect(find.text('Theo dõi theo danh mục'), findsOneWidget);
    });

    testWidgets('chưa có ngân sách tổng: mời tạo, không hiện "0 ₫ / ngày"', (tester) async {
      await pump(tester, AsyncValue.data(_stateWith()));

      expect(find.text('Bạn chưa đặt ngân sách tháng này'), findsOneWidget);
      expect(find.text('Tạo ngân sách tháng'), findsOneWidget);
      expect(find.textContaining('/ ngày'), findsNothing);
    });

    testWidgets('lỗi tải: hiện thông điệp thân thiện và nút Thử lại', (tester) async {
      await pump(tester, AsyncValue.error(Exception('Không có kết nối mạng'), StackTrace.empty));

      expect(find.text('Không có kết nối mạng'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('nhãn mức theo ngưỡng 70/90 và vượt hạn mức; không có khối AI giả', (tester) async {
      await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [
        _budget(categoryId: 'c1', category: 'A', limit: 100, spent: 50),
        _budget(categoryId: 'c2', category: 'B', limit: 100, spent: 80),
        _budget(categoryId: 'c3', category: 'C', limit: 100, spent: 95),
        _budget(categoryId: 'c4', category: 'D', limit: 100, spent: 120),
      ])));

      expect(find.text('50% An toàn'), findsOneWidget);
      expect(find.text('80% Cận hạn'), findsOneWidget);
      expect(find.text('95% Sát mức'), findsOneWidget);
      expect(find.text('120% Vượt hạn mức'), findsOneWidget);
      expect(find.text('FinMate Cố Vấn Thông Minh'), findsNothing);
    });

    testWidgets('nút "Tạo ngân sách mới" mở form không kèm ngân sách; bấm thẻ mở form kèm ngân sách', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [budget])));

      await tester.tap(find.text('Tạo ngân sách mới'));
      await tester.pumpAndSettle();
      expect(pushed.single, isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      pushed.clear();
      await tester.tap(find.byKey(ValueKey('budget-card-${budget.id}')));
      await tester.pumpAndSettle();
      expect((pushed.single as BudgetEntity).id, budget.id);
    });

    testWidgets('xoá ngân sách theo danh mục: xác nhận rồi gọi controller', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final mock = await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [budget])));

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
      final mock = await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [budget])));

      await tester.tap(find.byKey(ValueKey('delete-budget-${budget.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(mock.deletedBudgetIds, isEmpty);
    });

    testWidgets('chỉ 1 ngân sách danh mục: không hiện nút "Chuyển"', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [budget])));

      expect(find.text('Chuyển'), findsNothing);
    });

    testWidgets('chuyển hạn mức giữa 2 ngân sách danh mục: chọn nguồn/đích, nhập số tiền, gọi controller', (tester) async {
      final food = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final transport = _budget(categoryId: 'cat-2', category: 'Di chuyển', limit: 2000000, spent: 500000);
      final mock = await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [food, transport])));

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
      final mock = await pump(tester, AsyncValue.data(_stateWith(categoryBudgets: [food, transport])));

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

    testWidgets('360dp: không tràn ngang với tên dài, số tiền lớn, vượt hạn mức', (tester) async {
      await pump(
        tester,
        AsyncValue.data(_stateWith(
          overall: _budget(limit: 999999999999, spent: 1000000000000),
          categoryBudgets: [
            _budget(categoryId: 'c1', category: 'Ăn uống & Tiệc tùng và những khoản chi phát sinh khác', limit: 999999999999, spent: 999999999999),
            _budget(categoryId: 'c2', category: 'Di chuyển', limit: 3000000, spent: 4000000),
          ],
        )),
        width: 360,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
