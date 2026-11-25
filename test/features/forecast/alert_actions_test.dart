import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/features/analytics/presentation/screens/f4_alerts_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/alert_action_runner.dart';
import '../../fixtures/fixture.dart';

/// Nút hành động đi kèm cảnh báo dự báo (cảnh báo chủ động): backend tính nút từ loại cảnh báo, app chỉ hiện và gọi API có sẵn khi người dùng bấm.
Map<String, dynamic> _alert(String id, String kind, List<Map<String, dynamic>>? actions, {bool inaccurate = false}) => {
      'id': id,
      'kind': kind,
      'title': 'Tiêu đề $id',
      'body': 'Nội dung $id',
      'data': <String, dynamic>{},
      'status': 'sent',
      'scheduledFor': '2026-11-10T08:00:00Z',
      'sentAt': '2026-11-10T08:00:05Z',
      'markedInaccurate': inaccurate,
      'createdAt': '2026-11-10T08:00:00Z',
      if (actions != null) 'actions': actions,
    };

const _raise = {'kind': 'raise_budget_limit', 'title': 'Nâng hạn mức lên 3.420.000 đồng', 'amountCents': 3420000, 'categoryId': 'cat-food'};
const _total = {'kind': 'raise_budget_limit', 'title': 'Nâng hạn mức lên 12.000.000 đồng', 'amountCents': 12000000, 'categoryId': ''};
const _open = {'kind': 'open_forecast', 'title': 'Xem dự báo ngân sách'};
const _resume = {'kind': 'resume_recurring', 'title': 'Vẫn dùng, theo dõi lại', 'targetId': 'rec-1'};

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('đọc cảnh báo', () {
    test('có nút: đọc đúng loại, số tiền, nhóm, đối tượng; cảnh báo cũ không có trường actions thì rỗng', () {
      final withActions = ForecastAlertEntity.fromJson(_alert('a', 'budget_risk', [_raise, _open, _resume]));
      final old = ForecastAlertEntity.fromJson(_alert('b', 'budget_risk', null));

      expect(withActions.actions.map((a) => a.kind), ['raise_budget_limit', 'open_forecast', 'resume_recurring']);
      expect(withActions.actions[0].amountCents, BigInt.from(3420000));
      expect(withActions.actions[0].categoryId, 'cat-food');
      expect(withActions.actions[2].targetId, 'rec-1');
      expect(old.actions, isEmpty);
    });

    test('loại nút app chưa biết (backend mới hơn) bị bỏ qua, không làm hỏng cảnh báo', () {
      final alert = ForecastAlertEntity.fromJson(_alert('a', 'budget_risk', [
        {'kind': 'something_new', 'title': 'Loại mới'},
        _open,
      ]));

      expect(alert.actions.map((a) => a.kind), ['open_forecast']);
    });

    test('canRun: chỉ khi đủ dữ liệu cho việc của loại đó', () {
      expect(const ForecastAlertAction(kind: 'raise_budget_limit', title: 't', categoryId: 'c').canRun, isFalse, reason: 'thiếu số tiền');
      expect(ForecastAlertAction(kind: 'raise_budget_limit', title: 't', amountCents: BigInt.one).canRun, isFalse, reason: 'thiếu nhóm (cảnh báo cũ)');
      expect(ForecastAlertAction(kind: 'raise_budget_limit', title: 't', amountCents: BigInt.one, categoryId: '').canRun, isTrue, reason: 'nhóm rỗng = ngân sách tổng');
      expect(const ForecastAlertAction(kind: 'resume_recurring', title: 't').canRun, isFalse);
      expect(const ForecastAlertAction(kind: 'open_forecast', title: 't').canRun, isTrue);
    });
  });

  group('bộ chạy hành động', () {
    late List<(String?, BigInt)> raised;
    late List<String> resumed;
    Object? failWith;

    AlertActionRunner runner() => AlertActionRunner(
          raiseBudgetLimit: (category, limit) async {
            if (failWith != null) throw failWith!;
            raised.add((category, limit));
          },
          resumeRecurring: (id) async => resumed.add(id),
        );

    setUp(() {
      raised = [];
      resumed = [];
      failWith = null;
    });

    test('nâng hạn mức: đúng nhóm và số tiền; nhóm rỗng đổi thành null (ngân sách tổng)', () async {
      final r = runner();

      expect(await r.run(ForecastAlertAction.fromJson(Map<String, dynamic>.from(_raise))), isTrue);
      expect(await r.run(ForecastAlertAction.fromJson(Map<String, dynamic>.from(_total))), isTrue);

      expect(raised, [('cat-food', BigInt.from(3420000)), (null, BigInt.from(12000000))]);
    });

    test('theo dõi lại khoản định kỳ: gọi đúng id', () async {
      expect(await runner().run(ForecastAlertAction.fromJson(Map<String, dynamic>.from(_resume))), isTrue);

      expect(resumed, ['rec-1']);
    });

    test('mở dự báo là điều hướng của màn hình, thiếu dữ liệu thì không làm gì, lỗi API được ném lại để báo người dùng', () async {
      expect(await runner().run(ForecastAlertAction.fromJson(Map<String, dynamic>.from(_open))), isFalse);
      expect(await runner().run(const ForecastAlertAction(kind: 'raise_budget_limit', title: 't')), isFalse);
      expect(raised, isEmpty);
      expect(resumed, isEmpty);

      failWith = StateError('Không đặt được hạn mức.');
      await expectLater(runner().run(ForecastAlertAction.fromJson(Map<String, dynamic>.from(_raise))), throwsA(isA<StateError>()));
    });
  });

  group('màn cảnh báo', () {
    Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> alerts, {List<RequestOptions>? calls}) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ResponseBody route(RequestOptions o) {
        calls?.add(o);
        if (o.path.contains('/forecast/alerts')) return respondJson({'success': true, 'data': alerts, 'error': null, 'meta': null});
        if (o.path.contains('/anomalies')) return respondJson({'success': true, 'data': [], 'error': null, 'meta': null});
        if (o.path.contains('/recurring-items')) {
          return respondJson({
            'success': true,
            'data': {'id': 'rec-1', 'name': 'Tiền net', 'status': 'active', 'amountCents': 220000, 'nextDueDate': '2026-12-01'},
            'error': null,
            'meta': null,
          });
        }
        return respondFixture('categories');
      }

      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(testApiClient(RouteAdapter(route)))],
        child: const MaterialApp(home: F4AlertsScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('mỗi cảnh báo hiện nút của nó; cảnh báo cũ và cảnh báo đã báo "không chính xác" thì không có nút', (tester) async {
      await pump(tester, [
        _alert('al-1', 'budget_risk', [_raise, _open]),
        _alert('al-2', 'budget_risk', null),
        _alert('al-3', 'budget_risk', [_raise], inaccurate: true),
      ]);

      expect(find.text('Nâng hạn mức lên 3.420.000 đồng'), findsOneWidget, reason: 'chỉ cảnh báo al-1');
      expect(find.text('Xem dự báo ngân sách'), findsOneWidget);
      expect(find.byKey(const ValueKey('alert-action-al-2-0')), findsNothing);
      expect(find.byKey(const ValueKey('alert-action-al-3-0')), findsNothing);
    });

    testWidgets('bấm "Theo dõi lại" gọi API khoản định kỳ một lần rồi hiện "Đã theo dõi lại"', (tester) async {
      final calls = <RequestOptions>[];
      await pump(tester, [_alert('al-1', 'bill_status_check', [_resume])], calls: calls);

      await tester.tap(find.byKey(const ValueKey('alert-action-al-1-0')));
      await tester.pumpAndSettle();

      expect(find.text('Đã theo dõi lại'), findsOneWidget);
      expect(find.text('Vẫn dùng, theo dõi lại'), findsNothing);
      expect(calls.where((c) => c.path.contains('/recurring-items/rec-1')).length, 1);
    });
  });
}
