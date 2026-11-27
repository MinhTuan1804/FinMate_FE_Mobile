import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/data/planning_repository.dart';
import 'package:finmate/features/planning/domain/entities/market_topic.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/screens/goal_form_screen.dart';
import 'package:finmate/features/planning/presentation/screens/goals_screen.dart';
import '../../fixtures/fixture.dart';
import 'goal_test_support.dart';

/// Đúng dạng GET /saving-goals/market-topics trong docs/goals-and-reports-extras-api.md.
const _topicsJson = [
  {
    'key': 'gold',
    'label': 'Vàng',
    'priceCents': 85000000,
    'asOf': '2026-11-23T03:00:00Z',
    'nameKeywords': ['vàng', 'sjc'],
  },
];

final _gold = MarketTopic.fromJson(_topicsJson.first);

void main() {
  group('mô hình và repository', () {
    test('SavingsGoalEntity đọc trạng thái nháp và chủ đề giá', () {
      final g = SavingsGoalEntity.fromJson({
        'id': 'g1',
        'name': 'Mua vàng',
        'targetCents': 100,
        'savedCents': 0,
        'status': 'Draft',
        'marketTopic': 'gold',
      });

      expect(g.isDraft, isTrue);
      expect(g.marketTopic, 'gold');
      expect(g.copyWith(title: 'x').marketTopic, 'gold', reason: 'copyWith không làm mất chủ đề');
      expect(testGoal().isDraft, isFalse);
    });

    test('MarketTopic gợi ý theo từ khóa trong tên, không phân biệt hoa thường', () {
      expect(_gold.suggestedFor('Mua VÀNG cưới'), isTrue);
      expect(_gold.suggestedFor('Nhẫn sjc'), isTrue);
      expect(_gold.suggestedFor('Du lịch'), isFalse);
      expect(_gold.priceCents, BigInt.from(85000000));
    });

    test('createGoal gửi isDraft và marketTopic chỉ khi có; activateGoal và getMarketTopics gọi đúng đường dẫn', () async {
      final adapter = RouteAdapter((o) {
        if (o.path.endsWith('/market-topics')) return respondJson({'success': true, 'data': _topicsJson});
        if (o.path.endsWith('/activate')) return respondJson({'success': true, 'data': {'id': 'g1', 'name': 'A', 'targetCents': 100, 'savedCents': 0, 'status': 'active'}});
        return respondJson({'success': true, 'data': {'id': 'g1'}});
      });
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      await repo.createGoal(name: 'A', targetCents: BigInt.from(100));
      await repo.createGoal(name: 'B', targetCents: BigInt.from(100), isDraft: true, marketTopic: 'gold');
      final activated = await repo.activateGoal('g1');
      final topics = await repo.getMarketTopics();

      expect(adapter.requests[0].data, {'name': 'A', 'targetCents': 100}, reason: 'không gửi isDraft/marketTopic khi không dùng');
      expect(adapter.requests[1].data, containsPair('isDraft', true));
      expect(adapter.requests[1].data, containsPair('marketTopic', 'gold'));
      expect('${adapter.requests[2].method} ${adapter.requests[2].path}', 'POST /api/v1/saving-goals/g1/activate');
      expect(activated.status, 'active');
      expect('${adapter.requests[3].method} ${adapter.requests[3].path}', 'GET /api/v1/saving-goals/market-topics');
      expect(topics.single.key, 'gold');
    });

    test('updateGoal: marketTopic null = không gửi (giữ nguyên), chuỗi rỗng = bỏ theo giá', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': {'id': 'g1', 'name': 'A', 'targetCents': 100, 'savedCents': 0}}));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      await repo.updateGoal(id: 'g1', name: 'A', targetCents: BigInt.from(100));
      await repo.updateGoal(id: 'g1', name: 'A', targetCents: BigInt.from(100), marketTopic: '');

      expect((adapter.requests[0].data as Map).containsKey('marketTopic'), isFalse);
      expect(adapter.requests[1].data, containsPair('marketTopic', ''));
    });

    test('chủ đề giá lỗi (mất mạng, 5xx): provider cho ra danh sách rỗng thay vì lỗi', () async {
      final adapter = RouteAdapter((o) => ResponseBody.fromString('', 500));
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => 'u1'),
        planningRepositoryProvider.overrideWithValue(PlanningRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(marketTopicsProvider.future), isEmpty);
    });
  });

  group('màn danh sách: bản nháp', () {
    Future<MockGoalController> pump(WidgetTester tester, List<SavingsGoalEntity> goals, {void Function(MockGoalController)? prepare}) =>
        pumpGoalApp(tester, home: const GoalsScreen(), state: AsyncValue.data(planningWith(goals)), prepare: prepare);

    testWidgets('nháp có nhãn "Bản nháp" và nút Kích hoạt; không có nút Nạp tiền', (tester) async {
      await pump(tester, [testGoal(id: 'd1', title: 'Quỹ nháp', status: 'draft'), testGoal(id: 'a1', title: 'Quỹ chạy')]);

      expect(find.text('Bản nháp'), findsWidgets);
      expect(find.byKey(const ValueKey('activate-goal-d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('activate-goal-a1')), findsNothing);
      expect(find.text('Nạp tiền vào mục tiêu'), findsOneWidget, reason: 'chỉ mục tiêu đang chạy nạp được');
    });

    testWidgets('bản nháp không tính vào thẻ tổng và không tính là "đang chạy"', (tester) async {
      await pump(tester, [
        testGoal(id: 'd1', status: 'draft', current: 0, target: 90000000),
        testGoal(id: 'a1', current: 10000000, target: 40000000),
      ]);

      expect(find.text('Mục tiêu: 40.000.000 ₫'), findsOneWidget, reason: 'nháp 90 triệu không được cộng vào');
      expect(find.text('1 mục tiêu đang chạy'), findsOneWidget);
      expect(find.text('Bản nháp (1)'), findsOneWidget);
      expect(find.text('Đang chạy (1)'), findsOneWidget);
    });

    testWidgets('chỉ có nháp: không hiện thẻ tổng', (tester) async {
      await pump(tester, [testGoal(id: 'd1', status: 'draft')]);

      expect(find.textContaining('mục tiêu đang chạy'), findsNothing);
      expect(find.byKey(const ValueKey('activate-goal-d1')), findsOneWidget);
    });

    testWidgets('Kích hoạt gọi activateGoal rồi báo thành công', (tester) async {
      final mock = await pump(tester, [testGoal(id: 'd1', title: 'Quỹ nháp', status: 'draft')]);

      await tester.tap(find.byKey(const ValueKey('activate-goal-d1')));
      await tester.pumpAndSettle();

      expect(mock.activatedGoalIds, ['d1']);
      expect(find.text('Đã kích hoạt mục tiêu "Quỹ nháp".'), findsOneWidget);
    });

    testWidgets('BE từ chối (hạn chót đã qua): hiện thông điệp của BE, không báo thành công', (tester) async {
      final mock = await pump(tester, [testGoal(id: 'd1', status: 'draft')], prepare: (m) {
        m.activateError = BusinessRuleException(code: 'SAVING_GOAL_DEADLINE_PASSED', message: 'Hạn chót đã qua, hãy sửa hạn trước.', statusCode: 422);
      });

      await tester.tap(find.byKey(const ValueKey('activate-goal-d1')));
      await tester.pumpAndSettle();

      expect(mock.activatedGoalIds, isEmpty);
      expect(find.text('Hạn chót đã qua, hãy sửa hạn trước.'), findsOneWidget);
    });

    testWidgets('nháp hủy được từ danh sách (BE cho hủy nháp)', (tester) async {
      await pump(tester, [testGoal(id: 'd1', status: 'draft')]);

      expect(find.byKey(const ValueKey('cancel-goal-d1')), findsOneWidget);
    });
  });

  group('form: nháp và chủ đề giá', () {
    Future<MockGoalController> pump(WidgetTester tester, {SavingsGoalEntity? goal, List<MarketTopic> topics = const []}) =>
        pumpGoalApp(tester, home: GoalFormScreen(goal: goal), state: AsyncValue.data(planningWith(const [])), marketTopics: topics);

    Future<void> fill(WidgetTester tester, String name) async {
      await tester.enterText(find.byType(TextFormField).at(0), name);
      await tester.enterText(find.byType(TextFormField).at(1), '35000000');
      await tester.pump();
    }

    testWidgets('"Lưu bản nháp" gọi createSavingsGoal với isDraft', (tester) async {
      final mock = await pump(tester);

      await fill(tester, 'Du lịch');
      await tester.tap(find.byKey(const ValueKey('save-draft')));
      await tester.pumpAndSettle();

      expect(mock.goalCreates.single.isDraft, isTrue);
      expect(mock.goalCreates.single.title, 'Du lịch');
    });

    testWidgets('"Lưu mục tiêu" tạo mục tiêu thường (không phải nháp)', (tester) async {
      final mock = await pump(tester);

      await fill(tester, 'Du lịch');
      await tester.tap(find.byKey(const ValueKey('save-goal')));
      await tester.pumpAndSettle();

      expect(mock.goalCreates.single.isDraft, isFalse);
    });

    testWidgets('sửa mục tiêu: không có nút "Lưu bản nháp"', (tester) async {
      await pump(tester, goal: testGoal(deadline: DateTime(2027, 1, 1)));

      expect(find.byKey(const ValueKey('save-draft')), findsNothing);
    });

    testWidgets('BE không có chủ đề giá: không hiện lựa chọn theo giá', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('market-topic')), findsNothing);
    });

    testWidgets('tên có từ khóa: gợi ý theo giá vàng; bấm gợi ý chọn chủ đề và gửi marketTopic khi lưu', (tester) async {
      final mock = await pump(tester, topics: [_gold]);

      await fill(tester, 'Mua vàng cưới');
      await tester.ensureVisible(find.byKey(const ValueKey('suggest-topic-gold')));
      expect(find.text('Gợi ý: theo giá Vàng'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('suggest-topic-gold')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('suggest-topic-gold')), findsNothing, reason: 'đã chọn thì hết gợi ý');
      expect(find.textContaining('Vàng • 85.000.000'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('save-goal')));
      await tester.pumpAndSettle();

      expect(mock.goalCreates.single.marketTopic, 'gold');
    });

    testWidgets('tên không liên quan: không gợi ý và không tự gắn chủ đề', (tester) async {
      final mock = await pump(tester, topics: [_gold]);

      await fill(tester, 'Du lịch Đà Lạt');
      expect(find.byKey(const ValueKey('suggest-topic-gold')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('save-goal')));
      await tester.pumpAndSettle();

      expect(mock.goalCreates.single.marketTopic, isNull);
    });

    testWidgets('chọn chủ đề từ danh sách thả xuống', (tester) async {
      final mock = await pump(tester, topics: [_gold]);

      await fill(tester, 'Quỹ');
      await tester.ensureVisible(find.byKey(const ValueKey('market-topic')));
      await tester.tap(find.byKey(const ValueKey('market-topic')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Vàng • 85.000.000').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-goal')));
      await tester.pumpAndSettle();

      expect(mock.goalCreates.single.marketTopic, 'gold');
    });

    testWidgets('sửa mục tiêu đang theo giá: không đổi lựa chọn thì không gửi marketTopic (giữ nguyên)', (tester) async {
      final goal = testGoal(deadline: DateTime(2027, 1, 1)).copyWith(marketTopic: 'gold');
      final mock = await pump(tester, goal: goal, topics: [_gold]);

      await tester.tap(find.byKey(const ValueKey('save-goal')));
      await tester.pumpAndSettle();

      expect(mock.goalUpdates.single.marketTopic, isNull);
    });

    testWidgets('sửa mục tiêu đang theo giá: chọn "Không theo" thì gửi chuỗi rỗng để bỏ theo', (tester) async {
      final goal = testGoal(deadline: DateTime(2027, 1, 1)).copyWith(marketTopic: 'gold');
      final mock = await pump(tester, goal: goal, topics: [_gold]);

      await tester.ensureVisible(find.byKey(const ValueKey('market-topic')));
      await tester.tap(find.byKey(const ValueKey('market-topic')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không theo giá thị trường').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-goal')));
      await tester.pumpAndSettle();

      expect(mock.goalUpdates.single.marketTopic, '');
    });
  });
}
