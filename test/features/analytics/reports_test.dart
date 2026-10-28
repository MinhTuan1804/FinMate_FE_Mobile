import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import '../../fixtures/fixture.dart';

class MockPlanningController extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  MockPlanningController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MonthlySummary _summary({double? change, int spent = 45000, int prev = 0}) => MonthlySummary(
      totalSpentCents: BigInt.from(spent),
      totalIncomeCents: BigInt.from(20000000),
      netCents: BigInt.from(19955000),
      prevMonthSpentCents: BigInt.from(prev),
      transactionCount: 3,
      changePercent: change,
    );

CategoryBreakdown _breakdown(List<CategoryShare> items) =>
    CategoryBreakdown(totalSpentCents: items.fold(BigInt.zero, (a, b) => a + b.spentCents), items: items);

Forecast _forecast({int spent = 45000, int projected = 90000, int basedOn = 15, ForecastAdvice? advice}) => Forecast(
      spentSoFarCents: BigInt.from(spent),
      projectedSpendCents: BigInt.from(projected),
      daysElapsed: 15,
      daysInMonth: 30,
      basedOnDays: basedOn,
      confidence: 'medium',
      advice: advice,
    );

void main() {
  group('Mô hình báo cáo (response thật)', () {
    test('MonthlySummary.fromJson: changePercent null', () {
      final s = MonthlySummary.fromJson(fixtureData('monthly_summary') as Map<String, dynamic>);

      expect(s.totalSpentCents, BigInt.from(45000));
      expect(s.totalIncomeCents, BigInt.from(20000000));
      expect(s.netCents, BigInt.from(19955000));
      expect(s.transactionCount, 3);
      expect(s.changePercent, isNull);
    });

    test('CategoryBreakdown.fromJson: 1 mục food 100%', () {
      final b = CategoryBreakdown.fromJson(fixtureData('category_breakdown') as Map<String, dynamic>);

      expect(b.totalSpentCents, BigInt.from(45000));
      expect(b.items.single.name, 'Ăn uống');
      expect(b.items.single.slug, 'food');
      expect(b.items.single.percent, 100.0);
    });

    test('Forecast.fromJson: advice là object (khi đã có thu nhập), confidence medium', () {
      final f = Forecast.fromJson(fixtureData('forecast') as Map<String, dynamic>);

      expect(f.confidence, 'medium');
      expect(f.daysInMonth, 30);
      expect(f.projectedSpendCents, BigInt.from(45000));
      expect(f.advice, isNotNull);
      expect(f.advice!.monthlyIncomeCents, BigInt.from(15000000));
      expect(f.advice!.projectedBalanceCents, BigInt.from(14955000));
      expect(f.advice!.suggestedDailyCutCents, isNull);
    });

    test('Forecast.fromJson chịu được advice = null hoặc chuỗi cũ (không ném)', () {
      final base = Map<String, dynamic>.from(fixtureData('forecast') as Map);

      expect(Forecast.fromJson({...base, 'advice': null}).advice, isNull);
      expect(Forecast.fromJson({...base, 'advice': 'Hãy tiết kiệm hơn.'}).advice, isNull);
      final cut = Forecast.fromJson({
        ...base,
        'advice': {'monthlyIncomeCents': 1000, 'projectedBalanceCents': -500, 'suggestedDailyCutCents': 20000},
      }).advice!;
      expect(cut.projectedBalanceCents, BigInt.from(-500));
      expect(cut.suggestedDailyCutCents, BigInt.from(20000));
    });

    test('mục danh mục không có categoryId (chi không phân loại) vẫn parse được', () {
      final b = CategoryBreakdown.fromJson({
        'totalSpentCents': 100,
        'items': [
          {'categoryId': null, 'categoryName': null, 'categorySlug': null, 'spentCents': 100, 'percent': 100},
        ],
      });

      expect(b.items.single.name, 'Chưa phân loại');
      expect(b.items.single.categoryId, isNull);
    });
  });

  test('ReportsRepository gọi đúng endpoint và gửi year/month', () async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('monthly-summary')) return respondFixture('monthly_summary');
      if (o.path.contains('category-breakdown')) return respondFixture('category_breakdown');
      return respondFixture('forecast');
    });
    final repo = ReportsRepository(apiClient: testApiClient(adapter));

    await repo.getMonthlySummary(year: 2026, month: 9);
    await repo.getCategoryBreakdown(year: 2026, month: 9);
    await repo.getForecast();

    expect(adapter.requests[0].path, '/api/v1/reports/monthly-summary');
    expect(adapter.requests[0].queryParameters, {'year': 2026, 'month': 9});
    expect(adapter.requests[1].path, '/api/v1/reports/category-breakdown');
    expect(adapter.requests[2].path, '/api/v1/reports/forecast');
  });

  group('AnalyticsScreen', () {
    Future<void> pump(
      WidgetTester tester, {
      required MonthlySummary summary,
      required CategoryBreakdown breakdown,
      required Forecast forecast,
      Object? summaryError,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          monthlySummaryProvider.overrideWith((ref) async {
            if (summaryError != null) throw summaryError;
            return summary;
          }),
          categoryBreakdownProvider.overrideWith((ref) async => breakdown),
          forecastProvider.overrideWith((ref) async => forecast),
          planningControllerProvider.overrideWith(
            (ref) => MockPlanningController(const AsyncValue.data(PlanningState(overallBudget: null, categoryBudgets: [], savingsGoals: [], daysRemainingInMonth: 10))),
          ),
        ],
        child: const MaterialApp(home: AnalyticsScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('không có chi tiêu: trạng thái trống, ẩn thẻ so sánh khi changePercent = null', (tester) async {
      await pump(tester, summary: _summary(change: null, spent: 0), breakdown: _breakdown(const []), forecast: _forecast(spent: 0, projected: 0, basedOn: 0));

      expect(find.text('Chưa có chi tiêu tháng này'), findsOneWidget);
      expect(find.textContaining('Chi tiêu giảm'), findsNothing);
      expect(find.textContaining('Chi tiêu tăng'), findsNothing);
      expect(find.text('Chưa đủ dữ liệu để dự báo'), findsOneWidget);
    });

    testWidgets('có dữ liệu: chú giải lấy từ backend, so sánh giảm/tăng đúng chiều', (tester) async {
      await pump(
        tester,
        summary: _summary(change: -12.5, spent: 8800000, prev: 10000000),
        breakdown: _breakdown([
          CategoryShare(categoryId: 'c1', name: 'Ăn uống', slug: 'food', spentCents: BigInt.from(6600000), percent: 75),
          CategoryShare(categoryId: 'c2', name: 'Di chuyển', slug: 'transport', spentCents: BigInt.from(2200000), percent: 25),
        ]),
        forecast: _forecast(advice: ForecastAdvice(monthlyIncomeCents: BigInt.from(15000000), projectedBalanceCents: BigInt.from(-500000), suggestedDailyCutCents: BigInt.from(20000))),
      );

      expect(find.text('Chi tiêu giảm 12,5%'), findsOneWidget);
      expect(find.text('Bạn đã chi ít hơn 1.200.000 ₫ so với tháng trước.'), findsOneWidget);
      expect(find.text('Ăn uống (75%)'), findsOneWidget);
      expect(find.text('6.600.000 ₫'), findsOneWidget);
      expect(find.text('Thu nhập tháng'), findsOneWidget);
      expect(find.text('-500.000 ₫'), findsOneWidget); // số dư dự kiến cuối tháng (âm)
      expect(find.text('Gợi ý cắt giảm mỗi ngày'), findsOneWidget);
      expect(find.text('20.000 ₫'), findsOneWidget);
      expect(find.textContaining('24.500.000'), findsNothing); // số giả cũ
    });

    testWidgets('chi tiêu tăng: hiện "Chi tiêu tăng"', (tester) async {
      await pump(tester, summary: _summary(change: 20, spent: 12000000, prev: 10000000), breakdown: _breakdown(const []), forecast: _forecast());

      expect(find.text('Chi tiêu tăng 20%'), findsOneWidget);
      expect(find.text('Bạn đã chi nhiều hơn 2.000.000 ₫ so với tháng trước.'), findsOneWidget);
    });

    testWidgets('lỗi tải báo cáo: hiện thông điệp và nút Thử lại, không số giả', (tester) async {
      await pump(tester, summary: _summary(), breakdown: _breakdown(const []), forecast: _forecast(), summaryError: Exception('Không có kết nối mạng'));

      expect(find.text('Không có kết nối mạng'), findsOneWidget);
      expect(find.text('Thử lại'), findsWidgets);
    });

    testWidgets('bộ chọn kỳ: chỉ "Tháng này" bật, tuần và năm hiển thị "Sắp có"', (tester) async {
      await pump(tester, summary: _summary(), breakdown: _breakdown(const []), forecast: _forecast());

      expect(find.text('Tháng này'), findsOneWidget);
      expect(find.text('Tuần và năm sắp có.'), findsOneWidget);
    });
  });
}
