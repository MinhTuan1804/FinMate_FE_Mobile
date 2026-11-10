import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/forecast/data/forecast_repository.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('CashflowForecastEntity.fromJson', () {
    test('đọc đúng từ/đến, số dư, ngày thấp nhất, nguyên nhân chính và danh sách ngày', () {
      final cashflow = CashflowForecastEntity.fromJson(fixtureData('cashflow') as Map<String, dynamic>);

      expect(cashflow.from, DateTime.parse('2026-11-07'));
      expect(cashflow.to, DateTime.parse('2026-11-30'));
      expect(cashflow.startBalanceCents, BigInt.from(5000000));
      expect(cashflow.endBalanceCents, BigInt.from(3200000));
      expect(cashflow.lowestDay, DateTime.parse('2026-11-15'));
      expect(cashflow.lowestBalanceCents, BigInt.from(1000000));
      expect(cashflow.confidence, 'normal');
      expect(cashflow.basis, 'history');
      expect(cashflow.days, hasLength(2));
      expect(cashflow.days[1].events.single.label, 'Tiền nhà');
      expect(cashflow.days[1].events.single.recurringItemId, 'r1');
      expect(cashflow.mainCauses.single.formattedAmount, '4.000.000 ₫');
    });
  });

  group('SafeToSpendEntity.fromJson', () {
    test('đọc đúng kỳ tính, số tiền có thể chi, ví/hóa đơn/mục tiêu', () {
      final spendable = SafeToSpendEntity.fromJson(fixtureData('spendable') as Map<String, dynamic>);

      expect(spendable.periodBasis, 'month_end');
      expect(spendable.daysRemaining, 23);
      expect(spendable.spendableCents, BigInt.from(500000));
      expect(spendable.hasShortfall, isFalse);
      expect(spendable.accounts.single.name, 'Ví chính');
      expect(spendable.bills.single.label, 'Tiền nhà');
      expect(spendable.goals.single.name, 'Du lịch hè');
    });

    test('shortfallCents > 0 thì hasShortfall đúng và spendableCents = 0', () {
      final spendable = SafeToSpendEntity.fromJson(fixtureData('spendable_shortfall') as Map<String, dynamic>);

      expect(spendable.hasShortfall, isTrue);
      expect(spendable.spendableCents, BigInt.zero);
      expect(spendable.formattedShortfall, '3.000.000 ₫');
    });
  });

  group('ForecastRepository', () {
    test('getCashflow gửi accountId + to (yyyy-MM-dd) khi có truyền', () async {
      final adapter = RouteAdapter((o) => respondFixture('cashflow'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getCashflow(accountId: 'acc-1', to: DateTime(2026, 11, 30));

      final q = adapter.requests.single.queryParameters;
      expect(q['accountId'], 'acc-1');
      expect(q['to'], '2026-11-30');
      expect(result.endBalanceCents, BigInt.from(3200000));
    });

    test('getCashflow không truyền gì thì không gửi query (BE tự dùng mặc định)', () async {
      final adapter = RouteAdapter((o) => respondFixture('cashflow'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      await repo.getCashflow();

      expect(adapter.requests.single.queryParameters.containsKey('accountId'), isFalse);
      expect(adapter.requests.single.queryParameters.containsKey('to'), isFalse);
    });

    test('runScenario gửi đúng path, items (ngày yyyy-MM-dd, chiều, nhãn)', () async {
      final adapter = RouteAdapter((o) => respondFixture('cashflow_scenario'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.runScenario(items: [
        ScenarioItemInput(
          date: DateTime(2026, 11, 20),
          amountCents: BigInt.from(1500000),
          direction: RecurringDirection.outflow,
          label: 'Mua laptop',
        ),
      ]);

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/forecast/cashflow/scenario');
      expect(req.data, {
        'items': [
          {'date': '2026-11-20', 'amountCents': 1500000, 'direction': 'Outflow', 'label': 'Mua laptop'}
        ],
      });
      expect(result.endBalanceCents, BigInt.from(1700000));
    });

    test('runScenario không có label thì không gửi field label', () async {
      final adapter = RouteAdapter((o) => respondFixture('cashflow_scenario'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      await repo.runScenario(items: [
        ScenarioItemInput(date: DateTime(2026, 11, 20), amountCents: BigInt.from(1000), direction: RecurringDirection.inflow),
      ]);

      final item = (adapter.requests.single.data as Map)['items'][0] as Map;
      expect(item.containsKey('label'), isFalse);
      expect(item['direction'], 'Inflow');
    });

    test('getSpendable gọi đúng path và parse kết quả', () async {
      final adapter = RouteAdapter((o) => respondFixture('spendable'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getSpendable();

      expect(adapter.requests.single.path, '/api/v1/forecast/spendable');
      expect(result.spendableCents, BigInt.from(500000));
    });

    test('getBudgets gọi đúng path và parse danh sách (tổng + theo danh mục)', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_budgets'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getBudgets();

      expect(adapter.requests.single.path, '/api/v1/forecast/budgets');
      expect(result, hasLength(2));
      expect(result[0].isTotal, isTrue);
      expect(result[0].status, 'ok');
      expect(result[1].isTotal, isFalse);
      expect(result[1].categoryName, 'Ăn uống');
      expect(result[1].isOver, isTrue);
    });

    test('getIncome gọi đúng path và parse lịch thu nhập + khoản trễ', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_income'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getIncome();

      expect(adapter.requests.single.path, '/api/v1/forecast/income');
      expect(result.isRegular, isTrue);
      expect(result.upcoming.single.label, 'Lương tháng 11');
      expect(result.late.single.name, 'Freelance ABC');
      expect(result.late.single.daysLate, 6);
      expect(result.irregular, isNull);
    });

    test('getIncome parse được ước tính thu nhập không đều khi có', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_income_irregular'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getIncome();

      expect(result.isRegular, isFalse);
      expect(result.irregular, isNotNull);
      expect(result.irregular!.monthsUsed, 3);
      expect(result.irregular!.formattedConservativeMonthly, '4.000.000 ₫');
    });

    test('getAlerts gửi limit=20 mặc định và parse danh sách cảnh báo', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_alerts'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getAlerts();

      expect(adapter.requests.single.path, '/api/v1/forecast/alerts');
      expect(adapter.requests.single.queryParameters['limit'], 20);
      expect(result, hasLength(2));
      expect(result[0].kind, 'low_balance');
      expect(result[0].status, 'sent');
      expect(result[0].markedInaccurate, isFalse);
      expect(result[0].createdAt, DateTime.parse('2026-11-09T01:00:00Z').toLocal());
      expect(result[1].kind, 'budget_risk');
      expect(result[1].status, 'pending');
      expect(result[1].markedInaccurate, isTrue);
      expect(result[1].sentAt, isNull);
    });

    test('setAlertFeedback gửi feedback=inaccurate và parse lại cảnh báo đã cập nhật', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_alert_feedback'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.setAlertFeedback('al-1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/forecast/alerts/al-1/feedback');
      expect(req.data, {'feedback': 'inaccurate'});
      expect(result.markedInaccurate, isTrue);
    });

    test('getAnomalies mặc định (openOnly) không gửi status, trả danh sách bất thường', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_anomalies'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getAnomalies();

      final req = adapter.requests.single;
      expect(req.path, '/api/v1/forecast/anomalies');
      expect(req.queryParameters.containsKey('status'), isFalse);
      expect(req.queryParameters['limit'], 20);
      expect(result, hasLength(2));
      expect(result[0].kind, 'merchant_spike');
      expect(result[0].severity, 'high');
      expect(result[0].isResolved, isFalse);
      expect(result[0].merchantName, 'Nhà hàng ABC');
      expect(result[1].kind, 'duplicate');
      expect(result[1].isResolved, isTrue);
      expect(result[1].resolution, 'wrong_entry');
    });

    test('getAnomalies(openOnly: false) gửi status=all', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_anomalies'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      await repo.getAnomalies(openOnly: false);

      expect(adapter.requests.single.queryParameters['status'], 'all');
    });

    test('setAnomalyFeedback gửi resolution, parse lại anomaly (không có guidance)', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_anomaly_feedback'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.setAnomalyFeedback(anomalyId: 'an-1', resolution: 'one_off');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/forecast/anomalies/an-1/feedback');
      expect(req.data, {'resolution': 'one_off'});
      expect(result.anomaly.resolution, 'one_off');
      expect(result.guidance, isNull);
    });

    test('setAnomalyFeedback(resolution: suspicious) trả kèm hướng dẫn liên hệ ngân hàng', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_anomaly_feedback_suspicious'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.setAnomalyFeedback(anomalyId: 'an-1', resolution: 'suspicious');

      expect(result.anomaly.resolution, 'suspicious');
      expect(result.guidance, contains('ngân hàng'));
    });

    test('getCategoryForecast không truyền month thì không gửi query, parse đúng danh sách danh mục', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_categories'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getCategoryForecast();

      final req = adapter.requests.single;
      expect(req.path, '/api/v1/forecast/categories');
      expect(req.queryParameters.containsKey('month'), isFalse);
      expect(result.month, '2026-12');
      expect(result.availableMonths, ['2026-11', '2026-12']);
      expect(result.enoughHistory, isTrue);
      expect(result.items, hasLength(3));
      expect(result.items[0].categoryId, 'cat-1');
      expect(result.items[0].suggestedLimitCents, BigInt.from(3600000));
      expect(result.items[0].changedSignificantly, isTrue);
      expect(result.items[2].categoryId, isNull);
      expect(result.items[2].isUncategorized, isTrue);
      expect(result.items[2].suggestedLimitCents, isNull);
    });

    test('getCategoryForecast(month: ...) gửi đúng tháng dạng yyyy-MM', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_categories'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      await repo.getCategoryForecast(month: '2026-12');

      expect(adapter.requests.single.queryParameters['month'], '2026-12');
    });

    test('applyCategoryBudgets gửi đúng path, body (categoryId, limitCents) và parse kết quả (áp dụng từ kỳ sau)', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_categories_apply'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.applyCategoryBudgets([
        CategoryBudgetItemInput(categoryId: 'cat-1', limitCents: BigInt.from(3600000)),
      ]);

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/forecast/categories/apply');
      expect(req.data, {
        'items': [
          {'categoryId': 'cat-1', 'limitCents': 3600000}
        ],
      });
      expect(result.single.effective, 'next_period');
      expect(result.single.isNow, isFalse);
    });

    test('applyCategoryBudgets với danh mục chưa có ngân sách thì effective = now', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_categories_apply_now'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.applyCategoryBudgets([
        CategoryBudgetItemInput(categoryId: 'cat-2', limitCents: BigInt.from(500000)),
      ]);

      expect(result.single.isNow, isTrue);
      expect(result.single.formattedLimit, '500.000 ₫');
    });

    test('getGoalForecast không truyền scenarioMonthlyCents thì không gửi query, parse DateOnly không .toLocal()', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_goal'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getGoalForecast('g1');

      final req = adapter.requests.single;
      expect(req.path, '/api/v1/forecast/goals/g1');
      expect(req.queryParameters.containsKey('monthlyContributionCents'), isFalse);
      expect(result.goalStatus, 'active');
      expect(result.forecastStatus, 'on_track');
      expect(result.deadline, DateTime.parse('2027-06-30'));
      expect(result.likelyDate, DateTime.parse('2027-04-15'));
      expect(result.conservativeDate, DateTime.parse('2027-07-01'));
      expect(result.requiredMonthlyCents, BigInt.from(2500000));
      expect(result.isScenario, isFalse);
    });

    test('getGoalForecast(scenarioMonthlyCents: ...) gửi monthlyContributionCents trên query', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_goal_scenario'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getGoalForecast('g1', scenarioMonthlyCents: BigInt.from(5000000));

      expect(adapter.requests.single.queryParameters['monthlyContributionCents'], 5000000);
      expect(result.isScenario, isTrue);
      expect(result.forecastStatus, 'reached');
      expect(result.requiredMonthlyCents, isNull);
    });
  });

  group('ForecastRepository — cài đặt dự báo', () {
    test('getSettings gọi đúng path, parse dự phòng mặc định và danh sách ví', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_settings'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.getSettings();

      expect(adapter.requests.single.path, '/api/v1/me/forecast-settings');
      expect(adapter.requests.single.method, 'GET');
      expect(result.usesDefaultReserve, isTrue);
      expect(result.defaultReservePercentOfIncome, 20);
      expect(result.effectiveReserveCents, BigInt.from(2000000));
      expect(result.lowBalanceAlertEnabled, isTrue);
      expect(result.usesDefaultQuietHours, isTrue);
      expect(result.accounts, hasLength(2));
      expect(result.accounts[1].includeInForecast, isFalse);
    });

    test('updateSettings gửi đúng path, body và parse cài đặt đã lưu (dự phòng + giờ yên lặng riêng)', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_settings_updated'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.updateSettings(
        reserveCents: BigInt.from(3000000),
        quietHoursStart: '23:00',
        quietHoursEnd: '06:00',
        forecastAlertsEnabled: false,
      );

      final req = adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/v1/me/forecast-settings');
      expect(req.data, {
        'reserveCents': 3000000,
        'lowBalanceThresholdCents': null,
        'quietHoursStart': '23:00',
        'quietHoursEnd': '06:00',
        'forecastAlertsEnabled': false,
      });
      expect(result.usesDefaultReserve, isFalse);
      expect(result.formattedReserve, '3.000.000 ₫');
      expect(result.quietHoursStart, '23:00');
      expect(result.usesDefaultQuietHours, isFalse);
      expect(result.forecastAlertsEnabled, isFalse);
    });

    test('updateSettings không truyền gì thì gửi null cho dự phòng/ngưỡng/giờ yên lặng (dùng mặc định)', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_settings'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      await repo.updateSettings(forecastAlertsEnabled: true);

      expect(adapter.requests.single.data, {
        'reserveCents': null,
        'lowBalanceThresholdCents': null,
        'quietHoursStart': null,
        'quietHoursEnd': null,
        'forecastAlertsEnabled': true,
      });
    });

    test('setAccountInclusion gửi đúng path, body included và parse lại ví', () async {
      final adapter = RouteAdapter((o) => respondFixture('forecast_account_inclusion'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.setAccountInclusion('acc-2', true);

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/financial-accounts/acc-2/forecast-inclusion');
      expect(req.data, {'included': true});
      expect(result.includeInForecast, isTrue);
    });

    test('setTransactionExclusion(excluded: true) gửi kèm reason và parse lại trạng thái loại', () async {
      final adapter = RouteAdapter((o) => respondFixture('transaction_forecast_exclusion'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.setTransactionExclusion('tx-1', excluded: true, reason: 'one_off');

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/transactions/tx-1/forecast-exclusion');
      // BE nhận enum ForecastExclusionReason qua model binding nên cần PascalCase ("OneOff"), khác với
      // chuỗi snake_case ("one_off") mà BE trả về khi đọc — xem _exclusionReasonApiValue trong repository.
      expect(req.data, {'excluded': true, 'reason': 'OneOff'});
      expect(result.excludeFromForecast, isTrue);
      expect(result.reason, 'one_off');
    });

    test('setTransactionExclusion(excluded: false) không gửi reason và parse lại đã đưa về', () async {
      final adapter = RouteAdapter((o) => respondFixture('transaction_forecast_inclusion'));
      final repo = ForecastRepository(apiClient: testApiClient(adapter));

      final result = await repo.setTransactionExclusion('tx-1', excluded: false);

      final req = adapter.requests.single;
      expect(req.data, {'excluded': false});
      expect(result.excludeFromForecast, isFalse);
      expect(result.reason, isNull);
    });
  });
}
