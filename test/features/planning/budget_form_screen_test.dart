import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/planning/presentation/screens/budget_form_screen.dart';
import '../../fixtures/fixture.dart';

class _MockPlanning extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  final saved = <({String? categoryId, BigInt limit})>[];
  Object? failWith;

  _MockPlanning(super.state);

  @override
  Future<void> createOrUpdateBudget({String? categoryId, required BigInt limitAmountCents}) async {
    if (failWith != null) throw failWith!;
    saved.add((categoryId: categoryId, limit: limitAmountCents));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockThresholds extends StateNotifier<AsyncValue<AlertThresholdSettingsEntity>> implements AlertThresholdsController {
  _MockThresholds(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _thresholds = AlertThresholdSettingsEntity(
  t1Pct: 80,
  t2Pct: 100,
  source: 'system',
  methodCode: null,
  methodName: null,
  personal: null,
  systemDefault: ThresholdPairEntity(t1Pct: 80, t2Pct: 100),
);

BudgetEntity _budget({String? categoryId, String category = 'Tổng thể', int limit = 10000000, int spent = 0}) => BudgetEntity(
      id: 'b-$category',
      categoryId: categoryId,
      category: category,
      limitAmountCents: BigInt.from(limit),
      spentAmountCents: BigInt.from(spent),
      month: 10,
      year: 2026,
    );

void main() {
  group('BudgetFormScreen (G6)', () {
    late List<Category> categories;

    setUp(() => categories = (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList());

    Future<_MockPlanning> pump(
      WidgetTester tester, {
      BudgetEntity? budget,
      PlanningState? planning,
      AsyncValue<AlertThresholdSettingsEntity> thresholds = const AsyncValue.data(_thresholds),
      double width = 800,
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mock = _MockPlanning(AsyncValue.data(
        planning ?? const PlanningState(overallBudget: null, categoryBudgets: [], savingsGoals: [], daysRemainingInMonth: 10),
      ));
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: () => context.push('/form', extra: budget), child: const Text('open')),
          ),
        ),
        GoRoute(path: '/form', builder: (_, s) => BudgetFormScreen(budget: s.extra as BudgetEntity?)),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          planningControllerProvider.overrideWith((ref) => mock),
          alertThresholdsControllerProvider.overrideWith((ref) => _MockThresholds(thresholds)),
          categoriesProvider.overrideWith((ref) async => categories),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return mock;
    }

    testWidgets('người dùng mới: mặc định ngân sách tổng, lưu gọi controller với categoryId null rồi đóng màn', (tester) async {
      final mock = await pump(tester);
      expect(find.text('Thiết lập ngân sách'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('budget-limit-input')), '7000000');
      await tester.pump();
      expect(find.text('Lưu ngân sách (7.000.000 ₫)'), findsOneWidget);
      // ngưỡng thật 80%/100% tính từ hạn mức đang nhập
      expect(find.textContaining('80% · 5.600.000 ₫'), findsOneWidget);
      expect(find.textContaining('100% · 7.000.000 ₫'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('budget-save')));
      await tester.pumpAndSettle();

      expect(mock.saved.single, (categoryId: null, limit: BigInt.from(7000000)));
      expect(find.text('Thiết lập ngân sách'), findsNothing);
    });

    testWidgets('theo danh mục: phải chọn danh mục, sau đó lưu với categoryId đã chọn', (tester) async {
      final mock = await pump(
        tester,
        planning: PlanningState(overallBudget: _budget(), categoryBudgets: const [], savingsGoals: const [], daysRemainingInMonth: 10),
      );

      await tester.enterText(find.byKey(const ValueKey('budget-limit-input')), '2000000');
      await tester.tap(find.byKey(const ValueKey('budget-save')));
      await tester.pump();
      expect(find.text('Vui lòng chọn danh mục'), findsOneWidget);
      expect(mock.saved, isEmpty);

      await tester.tap(find.byKey(ValueKey('budget-cat-${categories.first.id}')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('budget-save')));
      await tester.pumpAndSettle();

      expect(mock.saved.single, (categoryId: categories.first.id, limit: BigInt.from(2000000)));
    });

    testWidgets('danh mục đã có ngân sách không xuất hiện trong danh sách chọn', (tester) async {
      final taken = _budget(categoryId: categories.first.id, category: categories.first.name);
      await pump(
        tester,
        planning: PlanningState(overallBudget: _budget(), categoryBudgets: [taken], savingsGoals: const [], daysRemainingInMonth: 10),
      );

      expect(find.byKey(ValueKey('budget-cat-${categories.first.id}')), findsNothing);
    });

    testWidgets('số tiền 0 hoặc rỗng bị chặn, không gọi controller', (tester) async {
      final mock = await pump(tester);

      await tester.enterText(find.byKey(const ValueKey('budget-limit-input')), '0');
      await tester.tap(find.byKey(const ValueKey('budget-save')));
      await tester.pump();

      expect(mock.saved, isEmpty);
      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
    });

    testWidgets('sửa ngân sách: điền sẵn hạn mức, khoá phạm vi, lưu giữ nguyên categoryId', (tester) async {
      final budget = _budget(categoryId: 'cat-1', category: 'Ăn uống', limit: 5000000, spent: 1000000);
      final mock = await pump(tester, budget: budget);

      expect(find.text('Sửa ngân sách'), findsOneWidget);
      expect(find.text('5.000.000'), findsOneWidget);
      expect(find.byKey(ValueKey('budget-cat-${categories.first.id}')), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('budget-limit-input')), '6000000');
      await tester.tap(find.byKey(const ValueKey('budget-save')));
      await tester.pumpAndSettle();

      expect(mock.saved.single, (categoryId: 'cat-1', limit: BigInt.from(6000000)));
    });

    testWidgets('lưu lỗi: báo thân thiện, ở lại màn hình', (tester) async {
      final mock = await pump(tester);
      mock.failWith = Exception('Không có kết nối mạng');

      await tester.enterText(find.byKey(const ValueKey('budget-limit-input')), '1000000');
      await tester.tap(find.byKey(const ValueKey('budget-save')));
      await tester.pumpAndSettle();

      expect(find.text('Không có kết nối mạng'), findsOneWidget);
      expect(find.text('Thiết lập ngân sách'), findsOneWidget);
    });

    testWidgets('chưa tải được ngưỡng: ẩn khối ngưỡng, không hiện dữ liệu giả; Hủy bỏ đóng màn', (tester) async {
      await pump(tester, thresholds: const AsyncValue.loading());

      expect(find.text('Ngưỡng cảnh báo'), findsNothing);
      expect(find.textContaining('Độ chuẩn xác'), findsNothing);
      expect(find.textContaining('tự cân chỉnh'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('budget-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Thiết lập ngân sách'), findsNothing);
    });

    testWidgets('360dp: không tràn ngang', (tester) async {
      await pump(
        tester,
        planning: PlanningState(overallBudget: _budget(), categoryBudgets: const [], savingsGoals: const [], daysRemainingInMonth: 10),
        width: 360,
      );
      await tester.enterText(find.byKey(const ValueKey('budget-limit-input')), '999999999999');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
