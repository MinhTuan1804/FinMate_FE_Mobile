import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/forecast/presentation/screens/forecast_screen.dart';
import 'package:finmate/features/planning/data/planning_repository.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: GET cashflow -> cashflow.json, GET spendable -> spendable.json,
/// GET budgets -> forecast_budgets.json, GET income -> forecast_income.json,
/// GET alerts -> forecast_alerts.json, POST alerts/{id}/feedback -> forecast_alert_feedback.json,
/// GET anomalies -> forecast_anomalies.json, POST anomalies/{id}/feedback -> forecast_anomaly_feedback.json,
/// POST cashflow/scenario -> cashflow_scenario.json. Ghi đè từng fixture để test các nhánh khác.
RouteAdapter _adapter({
  String spendableFixture = 'spendable',
  String scenarioFixture = 'cashflow_scenario',
  String budgetsFixture = 'forecast_budgets',
  String incomeFixture = 'forecast_income',
  String alertsFixture = 'forecast_alerts',
  String alertFeedbackFixture = 'forecast_alert_feedback',
  String anomaliesFixture = 'forecast_anomalies',
  String anomalyFeedbackFixture = 'forecast_anomaly_feedback',
  String categoriesFixture = 'forecast_categories',
  String applyCategoryFixture = 'forecast_categories_apply',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/cashflow/scenario')) return respondFixture(scenarioFixture);
    if (o.path.contains('/spendable')) return respondFixture(spendableFixture);
    if (o.path.contains('/budgets')) return respondFixture(budgetsFixture);
    if (o.path.contains('/income')) return respondFixture(incomeFixture);
    if (o.path.contains('/alerts') && o.path.contains('/feedback')) return respondFixture(alertFeedbackFixture);
    if (o.path.contains('/alerts')) return respondFixture(alertsFixture);
    if (o.path.contains('/anomalies') && o.path.contains('/feedback')) return respondFixture(anomalyFeedbackFixture);
    if (o.path.contains('/anomalies')) return respondFixture(anomaliesFixture);
    if (o.path.contains('/categories/apply')) return respondFixture(applyCategoryFixture);
    if (o.path.contains('/categories')) return respondFixture(categoriesFixture);
    return respondFixture('cashflow');
  });
}

/// Controller mục tiêu tiết kiệm giả, trả thẳng [goals] (không gọi API) để test phần dự báo mục tiêu.
class _FixedPlanningController extends PlanningController {
  _FixedPlanningController(List<SavingsGoalEntity> goals)
      : super(
          repository: PlanningRepository(apiClient: testApiClient(RouteAdapter((o) => throw UnimplementedError()))),
          enabled: false,
        ) {
    state = AsyncValue.data(PlanningState(overallBudget: null, categoryBudgets: const [], savingsGoals: goals, daysRemainingInMonth: 10));
  }
}

final _goal1 = SavingsGoalEntity(id: 'g1', title: 'Quỹ khẩn cấp', targetAmountCents: BigInt.from(45000000), currentAmountCents: BigInt.from(15000000));
final _goal2 = SavingsGoalEntity(id: 'g2', title: 'Mua xe máy', targetAmountCents: BigInt.from(30000000), currentAmountCents: BigInt.from(5000000));

/// Adapter đầy đủ các route cố định (cashflow/spendable/budgets/income/alerts/anomalies/categories) kèm route /goals/
/// để test phần dự báo mục tiêu; [goalFixture] cho tải thường, [scenarioFixture] khi có query monthlyContributionCents.
RouteAdapter _adapterWithGoal({String goalFixture = 'forecast_goal', String? scenarioFixture, Map<String, String>? goalFixtureByPath}) {
  return RouteAdapter((o) {
    if (o.path.contains('/cashflow/scenario')) return respondFixture('cashflow_scenario');
    if (o.path.contains('/spendable')) return respondFixture('spendable');
    if (o.path.contains('/budgets')) return respondFixture('forecast_budgets');
    if (o.path.contains('/income')) return respondFixture('forecast_income');
    if (o.path.contains('/alerts') && o.path.contains('/feedback')) return respondFixture('forecast_alert_feedback');
    if (o.path.contains('/alerts')) return respondFixture('forecast_alerts');
    if (o.path.contains('/anomalies') && o.path.contains('/feedback')) return respondFixture('forecast_anomaly_feedback');
    if (o.path.contains('/anomalies')) return respondFixture('forecast_anomalies');
    if (o.path.contains('/categories/apply')) return respondFixture('forecast_categories_apply');
    if (o.path.contains('/categories')) return respondFixture('forecast_categories');
    if (o.path.contains('/goals/')) {
      if (scenarioFixture != null && o.queryParameters.containsKey('monthlyContributionCents')) {
        return respondFixture(scenarioFixture);
      }
      if (goalFixtureByPath != null) {
        for (final entry in goalFixtureByPath.entries) {
          if (o.path.contains(entry.key)) return respondFixture(entry.value);
        }
      }
      return respondFixture(goalFixture);
    }
    return respondFixture('cashflow');
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: ForecastScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('ForecastScreen', () {
    testWidgets('hiện dự báo dòng tiền và số tiền có thể chi từ dữ liệu thật', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Dự báo dòng tiền'), findsOneWidget);
      // "Đã chi 3.200.000 ₫ / ..." ở thẻ ngân sách trùng số tiền với số dư cuối kỳ, nên phải khớp cả tiền tố.
      expect(find.textContaining('cuối kỳ: 3.200.000 ₫'), findsOneWidget); // số dư cuối kỳ
      // Dùng dấu "• " để phân biệt với dòng "hóa đơn sắp tới" trùng tên/số tiền trong fixture.
      expect(find.textContaining('• Tiền nhà: 4.000.000 ₫'), findsOneWidget); // nguyên nhân chính

      expect(find.text('Số tiền có thể chi'), findsOneWidget);
      expect(find.textContaining('Có thể chi: 500.000 ₫'), findsOneWidget);
      expect(find.text('Du lịch hè: để dành 300.000 ₫'), findsOneWidget);
    });

    testWidgets('thiếu tiền (shortfall) hiện màu cảnh báo và không hiện số/ngày', (tester) async {
      await _pump(tester, _adapter(spendableFixture: 'spendable_shortfall'));

      expect(find.textContaining('Thiếu 3.000.000 ₫'), findsOneWidget);
      expect(find.textContaining('/ ngày'), findsNothing);
    });

    testWidgets('thử kịch bản: nhập khoản chi giả định, xem kết quả mới, có thể xem lại dự báo gốc', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('forecast-scenario-button')));
      await tester.pumpAndSettle();

      // "Thử kịch bản" cũng là label của nút mở hộp thoại nên phải thu hẹp vào title của AlertDialog.
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Thử kịch bản')), findsOneWidget);
      // Chưa nhập số tiền: nút xác nhận bị khoá
      final confirmBefore = tester.widget<TextButton>(find.byKey(const ValueKey('confirm-scenario')));
      expect(confirmBefore.onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('scenario-amount')), '1.500.000');
      await tester.enterText(find.byKey(const ValueKey('scenario-label')), 'Mua laptop');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('confirm-scenario')));
      await tester.pumpAndSettle();

      // Hiện kết quả kịch bản (số dư cuối kỳ mới) và nhãn cảnh báo "giả định"
      expect(find.textContaining('1.700.000 ₫'), findsOneWidget);
      expect(find.text('Đang xem kịch bản giả định (chưa lưu)'), findsOneWidget);
      expect(find.byKey(const ValueKey('forecast-reset-scenario')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('forecast-reset-scenario')));
      await tester.pumpAndSettle();

      // Trùng số tiền với thẻ ngân sách (xem chú thích ở test đầu), nên khớp cả tiền tố.
      expect(find.textContaining('cuối kỳ: 3.200.000 ₫'), findsOneWidget);
      expect(find.text('Đang xem kịch bản giả định (chưa lưu)'), findsNothing);
    });

    testWidgets('thử kịch bản: thiếu ghi chú (BE bắt buộc) thì khóa nút xác nhận', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('forecast-scenario-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('scenario-amount')), '1.500.000');
      await tester.pump();

      final confirmNoLabel = tester.widget<TextButton>(find.byKey(const ValueKey('confirm-scenario')));
      expect(confirmNoLabel.onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('scenario-label')), '   ');
      await tester.pump();

      // Chỉ khoảng trắng cũng không hợp lệ (trim rỗng)
      final confirmBlankLabel = tester.widget<TextButton>(find.byKey(const ValueKey('confirm-scenario')));
      expect(confirmBlankLabel.onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('scenario-label')), 'Mua laptop');
      await tester.pump();

      final confirmWithLabel = tester.widget<TextButton>(find.byKey(const ValueKey('confirm-scenario')));
      expect(confirmWithLabel.onPressed, isNotNull);
    });

    testWidgets('hiện ngân sách dự kiến: tổng (ok) và theo danh mục (vượt hạn mức)', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Ngân sách dự kiến'), findsOneWidget);
      expect(find.text('Tổng chi'), findsOneWidget);
      expect(find.text('Trong hạn mức'), findsOneWidget);
      // "Ăn uống" cũng là tên danh mục trong thẻ "Dự báo chi tiêu theo danh mục" mới thêm, nên thu hẹp vào đúng dòng ngân sách.
      expect(
        find.descendant(of: find.byKey(const ValueKey('budget-forecast-b2')), matching: find.text('Ăn uống')),
        findsOneWidget,
      );
      expect(find.text('Đã vượt hạn mức'), findsOneWidget);
      expect(find.textContaining('Đã chi 3.200.000 ₫ / 3.000.000 ₫'), findsOneWidget);
    });

    testWidgets('hiện thu nhập dự kiến: sắp tới và trễ hạn', (tester) async {
      await _pump(tester, _adapter());

      // "Thu nhập dự kiến" cũng là tên 1 dòng trong bảng "Số tiền có thể chi" (chữ thường, cỡ nhỏ),
      // nên phải thu hẹp vào đúng tiêu đề thẻ (đậm, cỡ lớn) để không khớp nhầm.
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Thu nhập dự kiến' && w.style?.fontWeight == FontWeight.w700),
        findsOneWidget,
      );
      expect(find.textContaining('Lương tháng 11: 15.000.000 ₫'), findsOneWidget);
      expect(find.textContaining('Freelance ABC: 2.000.000 ₫ (trễ 6 ngày'), findsOneWidget);
    });

    testWidgets('thu nhập không đều hiện mức thận trọng và đã nhận tháng này', (tester) async {
      await _pump(tester, _adapter(incomeFixture: 'forecast_income_irregular'));

      expect(find.textContaining('Mức thận trọng: 4.000.000 ₫/tháng'), findsOneWidget);
      expect(find.textContaining('Đã nhận tháng này: 1.200.000 ₫'), findsOneWidget);
    });

    testWidgets('chưa có ngân sách nào thì hiện thông báo rỗng', (tester) async {
      await _pump(tester, RouteAdapter((o) {
        if (o.path.contains('/budgets')) return respondJson({'success': true, 'data': <dynamic>[], 'error': null, 'meta': null});
        if (o.path.contains('/spendable')) return respondFixture('spendable');
        if (o.path.contains('/income')) return respondFixture('forecast_income');
        if (o.path.contains('/alerts')) return respondFixture('forecast_alerts');
        if (o.path.contains('/anomalies')) return respondFixture('forecast_anomalies');
        return respondFixture('cashflow');
      }));

      expect(find.text('Chưa có ngân sách nào được đặt cho tháng này.'), findsOneWidget);
    });

    testWidgets('hiện cảnh báo dự báo: tiêu đề, trạng thái, đã báo không chính xác', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Cảnh báo dự báo'), findsOneWidget);
      expect(find.text('Số dư sắp xuống dưới mức bạn đặt'), findsOneWidget);
      expect(find.text('Có thể vượt ngân sách Ăn uống'), findsOneWidget);
      // Chỉ al-2 đã báo không chính xác từ trước (al-1 chưa).
      expect(find.text('Đã báo không chính xác'), findsOneWidget);
      expect(find.byKey(const ValueKey('alert-mark-inaccurate-al-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('alert-mark-inaccurate-al-2')), findsNothing);
    });

    testWidgets('báo cảnh báo không chính xác: bấm nút thì ẩn nút và hiện đã báo', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('alert-mark-inaccurate-al-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('alert-mark-inaccurate-al-1')), findsNothing);
      expect(find.text('Đã báo không chính xác'), findsNWidgets(2));
    });

    testWidgets('chưa có cảnh báo nào thì hiện thông báo rỗng', (tester) async {
      await _pump(tester, RouteAdapter((o) {
        if (o.path.contains('/alerts')) return respondJson({'success': true, 'data': <dynamic>[], 'error': null, 'meta': null});
        if (o.path.contains('/anomalies')) return respondFixture('forecast_anomalies');
        if (o.path.contains('/spendable')) return respondFixture('spendable');
        if (o.path.contains('/budgets')) return respondFixture('forecast_budgets');
        if (o.path.contains('/income')) return respondFixture('forecast_income');
        return respondFixture('cashflow');
      }));

      expect(find.text('Chưa có cảnh báo nào.'), findsOneWidget);
    });

    testWidgets('hiện khoản bất thường: đang mở và đã phản hồi', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Khoản bất thường'), findsOneWidget);
      expect(find.textContaining('Cao bất thường theo nơi nhận · Nhà hàng ABC'), findsOneWidget);
      expect(find.textContaining('1.200.000 ₫ (gấp 4.0 lần mức thường: 300.000 ₫)'), findsOneWidget);
      expect(find.text('Đã phản hồi: Nhập sai'), findsOneWidget);
      expect(find.byKey(const ValueKey('anomaly-feedback-one_off-an-1')), findsOneWidget);
    });

    testWidgets('gửi phản hồi bất thường (chi một lần) thì cập nhật trạng thái', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('anomaly-feedback-one_off-an-1')));
      await tester.pumpAndSettle();

      expect(find.text('Đã phản hồi: Chi một lần'), findsOneWidget);
      expect(find.byKey(const ValueKey('anomaly-feedback-one_off-an-1')), findsNothing);
    });

    testWidgets('phản hồi "giao dịch lạ" hiện hộp thoại hướng dẫn liên hệ ngân hàng', (tester) async {
      await _pump(tester, _adapter(anomalyFeedbackFixture: 'forecast_anomaly_feedback_suspicious'));

      await tester.tap(find.byKey(const ValueKey('anomaly-feedback-suspicious-an-1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('tổng đài ngân hàng'), findsOneWidget);

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
    });

    testWidgets('chuyển sang "Tất cả" thì gửi status=all cho khoản bất thường', (tester) async {
      final requestedQueries = <Map<String, dynamic>>[];
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/anomalies')) {
          requestedQueries.add(o.queryParameters);
          return respondFixture('forecast_anomalies');
        }
        if (o.path.contains('/alerts')) return respondFixture('forecast_alerts');
        if (o.path.contains('/spendable')) return respondFixture('spendable');
        if (o.path.contains('/budgets')) return respondFixture('forecast_budgets');
        if (o.path.contains('/income')) return respondFixture('forecast_income');
        return respondFixture('cashflow');
      });
      await _pump(tester, adapter);

      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();

      expect(requestedQueries.last['status'], 'all');
    });

    testWidgets('không có khoản bất thường đang mở thì hiện thông báo rỗng', (tester) async {
      await _pump(tester, RouteAdapter((o) {
        if (o.path.contains('/anomalies')) return respondJson({'success': true, 'data': <dynamic>[], 'error': null, 'meta': null});
        if (o.path.contains('/alerts')) return respondFixture('forecast_alerts');
        if (o.path.contains('/spendable')) return respondFixture('spendable');
        if (o.path.contains('/budgets')) return respondFixture('forecast_budgets');
        if (o.path.contains('/income')) return respondFixture('forecast_income');
        return respondFixture('cashflow');
      }));

      expect(find.text('Không có khoản bất thường đang mở.'), findsOneWidget);
    });

    testWidgets('hiện dự báo chi tiêu theo danh mục: tổng, từng danh mục, nhãn cơ sở/độ tin cậy', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Dự báo chi tiêu theo danh mục'), findsOneWidget);
      expect(find.textContaining('Tổng dự kiến: 8.000.000 ₫ (tháng trước: 7.000.000 ₫)'), findsOneWidget);

      expect(find.byKey(const ValueKey('category-forecast-cat-1')), findsOneWidget);
      expect(find.textContaining('Dự kiến 3.500.000 ₫ (tháng trước 3.000.000 ₫, +17%)'), findsOneWidget);
      expect(find.textContaining('Lịch sử chi tiêu · Độ tin cậy: Bình thường'), findsOneWidget);
      expect(find.textContaining('Ngân sách hiện tại: 3.000.000 ₫'), findsOneWidget);
      expect(find.byKey(const ValueKey('apply-category-budget-cat-1')), findsOneWidget);
      expect(find.text('Dùng 3.600.000 ₫ làm ngân sách'), findsOneWidget);

      // Danh mục "Chưa phân loại" (categoryId null) không có hạn mức đề xuất -> không có nút áp dụng.
      expect(find.byKey(const ValueKey('category-forecast-uncategorized')), findsOneWidget);
      expect(find.text('Chưa phân loại'), findsOneWidget);
    });

    testWidgets('chưa đủ dữ liệu lịch sử thì hiện cảnh báo và không có danh mục nào', (tester) async {
      await _pump(tester, _adapter(categoriesFixture: 'forecast_categories_low_history'));

      expect(find.textContaining('Chưa đủ dữ liệu lịch sử (mới có 1 tháng)'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu để dự báo.'), findsOneWidget);
    });

    testWidgets('áp dụng ngân sách đề xuất cho danh mục đã có ngân sách thì áp dụng từ kỳ sau', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('apply-category-budget-cat-1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã đặt hạn mức mới 3.600.000 ₫ cho Ăn uống, áp dụng từ kỳ sau.'), findsOneWidget);
    });

    testWidgets('áp dụng ngân sách đề xuất cho danh mục chưa có ngân sách thì áp dụng ngay', (tester) async {
      await _pump(tester, _adapter(applyCategoryFixture: 'forecast_categories_apply_now'));

      await tester.tap(find.byKey(const ValueKey('apply-category-budget-cat-2')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã tạo ngân sách 500.000 ₫ cho Di chuyển, áp dụng ngay.'), findsOneWidget);
    });

    testWidgets('chưa có mục tiêu tiết kiệm nào thì hiện thông báo rỗng', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Dự báo mục tiêu tiết kiệm'), findsOneWidget);
      expect(find.text('Bạn chưa có mục tiêu tiết kiệm nào.'), findsOneWidget);
    });

    testWidgets('có mục tiêu thì chọn mục tiêu đầu tiên theo mặc định và hiện dự báo', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(testApiClient(_adapterWithGoal())),
          planningControllerProvider.overrideWith((ref) => _FixedPlanningController([_goal1, _goal2])),
        ],
        child: const MaterialApp(home: ForecastScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('goal-forecast-select')), findsOneWidget);
      expect(find.textContaining('Đã để dành 15.000.000 ₫ / 45.000.000 ₫ (33%) · Đang thực hiện'), findsOneWidget);
      expect(find.textContaining('Đang đúng tiến độ · Độ tin cậy: Bình thường'), findsOneWidget);
      expect(find.text('Với tốc độ hiện tại, bạn sẽ đạt mục tiêu trước hạn chót.'), findsOneWidget);
      expect(find.textContaining('Trung bình: 3.000.000 ₫/tháng · Thận trọng: 2.000.000 ₫/tháng'), findsOneWidget);
    });

    testWidgets('đổi mục tiêu trong dropdown thì tải và hiện dự báo của mục tiêu khác', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(testApiClient(_adapterWithGoal(
            goalFixtureByPath: {'/goals/g1': 'forecast_goal', '/goals/g2': 'forecast_goal_behind'},
          ))),
          planningControllerProvider.overrideWith((ref) => _FixedPlanningController([_goal1, _goal2])),
        ],
        child: const MaterialApp(home: ForecastScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goal-forecast-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mua xe máy').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã để dành 5.000.000 ₫ / 30.000.000 ₫ (17%)'), findsOneWidget);
      expect(find.textContaining('Có thể không kịp hạn'), findsOneWidget);
    });

    testWidgets('thử mức góp khác: xem kết quả giả định rồi xem lại dự báo gốc', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(testApiClient(_adapterWithGoal(scenarioFixture: 'forecast_goal_scenario'))),
          planningControllerProvider.overrideWith((ref) => _FixedPlanningController([_goal1])),
        ],
        child: const MaterialApp(home: ForecastScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goal-scenario-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('goal-scenario-amount')), '5.000.000');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-goal-scenario')));
      await tester.pumpAndSettle();

      expect(find.text('Đang xem theo mức góp giả định (chưa lưu)'), findsOneWidget);
      expect(find.textContaining('Đã đạt mục tiêu'), findsWidgets);
      expect(find.text('Với mức góp giả định, bạn sẽ đạt mục tiêu sớm hơn dự kiến.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('goal-reset-scenario')));
      await tester.pumpAndSettle();

      expect(find.text('Đang xem theo mức góp giả định (chưa lưu)'), findsNothing);
      expect(find.text('Với tốc độ hiện tại, bạn sẽ đạt mục tiêu trước hạn chót.'), findsOneWidget);
    });

    testWidgets('lỗi khi tải dự báo hiện thông điệp và nút Thử lại', (tester) async {
      await _pump(tester, RouteAdapter((o) => throwNetworkDown(o)));

      expect(find.text('Thử lại'), findsWidgets);
    });
  });
}
