import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/chat_cards.dart';
import '../../fixtures/fixture.dart';

/// Đặt mục tiêu tiết kiệm bằng chat: thẻ xác nhận, KHÔNG bao giờ tự tạo; chỉ bấm "Tạo mục tiêu" mới gọi tạo (đúng một lần).
/// JSON dưới đây có hình dạng đúng như `ChatGoalDraftDto` của backend (camelCase), đã được ghim bằng test hợp đồng ở backend.
Map<String, dynamic> goalJson({String? deadline, String? deadlineText = '2 tháng sau', bool nameIsDefault = false, String name = 'Mua xe máy'}) => {
      'action': 'goal',
      'intent': 'create_goal',
      'replyText': 'Mình hiểu mục tiêu của bạn như thế này. Bạn kiểm tra rồi bấm Tạo mục tiêu nhé.',
      'goal': {
        'name': name,
        'nameIsDefault': nameIsDefault,
        'targetCents': 50000000,
        'deadline': deadline,
        'deadlineText': deadlineText,
      },
    };

class _Repo extends AssistantRepository {
  final Map<String, dynamic> reply;
  _Repo(this.reply) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async => ChatReply.fromJson(reply);
}

void main() {
  late List<(String, BigInt, DateTime?)> created;
  late Object? failWith;

  AssistantController controller(Map<String, dynamic> reply, {bool withCreate = true}) => AssistantController(
        repository: _Repo(reply),
        retryEvery: null,
        createGoal: withCreate
            ? (name, target, deadline) async {
                if (failWith != null) throw failWith!;
                created.add((name, target, deadline));
              }
            : null,
      );

  String inTwoMonths() => DateTime.now().add(const Duration(days: 62)).toUtc().toIso8601String();

  setUp(() {
    created = [];
    failWith = null;
  });

  group('đọc phản hồi', () {
    test('phản hồi goal của backend thành bản nháp mục tiêu, hạn đọc đúng', () {
      final reply = ChatReply.fromJson(goalJson(deadline: '2026-12-17T23:59:59+07:00'));

      expect(reply.action, ChatAction.goal);
      final goal = reply.goal!;
      expect((goal.name, goal.nameIsDefault, goal.targetCents, goal.deadlineText), ('Mua xe máy', false, BigInt.from(50000000), '2 tháng sau'));
      expect(goal.deadline!.isAtSameMomentAs(DateTime.utc(2026, 12, 17, 16, 59, 59)), isTrue);
    });

    test('action goal mà thiếu goal thì chỉ là câu trả lời văn bản, không ném', () {
      final reply = ChatReply.fromJson({'action': 'goal', 'intent': 'create_goal', 'replyText': 'Bạn muốn tiết kiệm bao nhiêu?'});
      expect(reply.action, ChatAction.reply);
      expect(reply.goal, isNull);
      expect(reply.replyText, contains('bao nhiêu'));
    });

    test('phản hồi analyze (local-first) có goal; server cũ không có thì goal = null', () {
      final analysis = ChatAnalysis.fromJson({'intent': 'create_goal', 'goal': goalJson()['goal']});
      expect(analysis.goal!.name, 'Mua xe máy');
      expect(ChatAnalysis.fromJson({'intent': 'add_expense'}).goal, isNull);
    });

    test('không hạn là hợp lệ; số tiền mỗi tháng tính như màn Kế hoạch (làm tròn lên, tối thiểu 1 tháng)', () {
      final noDeadline = GoalDraft.fromJson(goalJson(deadlineText: null)['goal'] as Map<String, dynamic>);
      expect(noDeadline.deadline, isNull);
      expect(noDeadline.requiredPerMonth(), isNull);

      final now = DateTime(2026, 10, 17, 12);
      GoalDraft due(DateTime d) => GoalDraft(name: 'x', targetCents: BigInt.from(50000000), deadline: d);
      expect(due(DateTime(2026, 12, 17, 23, 59, 59)).requiredPerMonth(asOf: now), BigInt.from(25000000)); // 2 tháng
      expect(due(DateTime(2026, 10, 30, 23, 59, 59)).requiredPerMonth(asOf: now), BigInt.from(50000000)); // trong tháng này: tối thiểu 1 tháng
    });

    test('sửa tên thì không còn là tên mặc định; đổi hạn bằng tay thì bỏ cụm đã nói', () {
      final goal = GoalDraft(name: 'Mục tiêu tiết kiệm', nameIsDefault: true, targetCents: BigInt.one, deadlineText: '2 tháng sau');
      expect(goal.copyWith(name: 'Mua xe').nameIsDefault, isFalse);
      expect(goal.copyWith(deadline: DateTime(2027, 1, 1)).deadlineText, isNull);
      expect(goal.copyWith(targetCents: BigInt.two).nameIsDefault, isTrue);
    });
  });

  group('thẻ trong chat', () {
    test('câu đặt mục tiêu hiện lời nhắn rồi MỘT thẻ, và chưa tạo gì', () async {
      final c = controller(goalJson(deadline: inTwoMonths()));
      await c.send('đặt mục tiêu vào 2 tháng sau tôi sẽ mua được xe máy khoảng 50 triệu');

      expect(c.state.messages.whereType<AssistantText>().single.text, contains('mục tiêu'));
      final card = c.state.messages.whereType<GoalDraftCard>().single;
      expect((card.goal.name, card.status), ('Mua xe máy', GoalCardStatus.pending));
      expect(created, isEmpty);
      expect(c.state.messages.whereType<DraftCard>(), isEmpty); // không phải một khoản chi/chuyển tiền
    });

    test('Tạo mục tiêu: gọi tạo đúng một lần với tên, số tiền, hạn đã hiểu; bấm lại không tạo lần hai', () async {
      final c = controller(goalJson(deadline: inTwoMonths()));
      await c.send('đặt mục tiêu mua xe máy 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      await c.confirmGoal(id);
      await c.confirmGoal(id);

      expect(created, hasLength(1));
      expect((created.single.$1, created.single.$2), ('Mua xe máy', BigInt.from(50000000)));
      expect(created.single.$3, isNotNull);
      expect(c.state.messages.whereType<GoalDraftCard>().single.status, GoalCardStatus.created);
    });

    test('tạo lỗi: thẻ về trạng thái chờ kèm lý do, bấm lại được và không tạo trùng', () async {
      final c = controller(goalJson());
      await c.send('đặt mục tiêu mua xe máy 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      failWith = Exception('mất mạng');
      await c.confirmGoal(id);
      var card = c.state.messages.whereType<GoalDraftCard>().single;
      expect(card.status, GoalCardStatus.pending);
      expect(card.error, isNotNull);
      expect(created, isEmpty);

      failWith = null;
      await c.confirmGoal(id);
      card = c.state.messages.whereType<GoalDraftCard>().single;
      expect(card.status, GoalCardStatus.created);
      expect(card.error, isNull);
      expect(created, hasLength(1));
    });

    test('hủy: không tạo gì, và thẻ đã hủy không bấm tạo được nữa', () async {
      final c = controller(goalJson());
      await c.send('đặt mục tiêu mua xe máy 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      c.cancelGoal(id);
      await c.confirmGoal(id);

      expect(created, isEmpty);
      expect(c.state.messages.whereType<GoalDraftCard>().single.status, GoalCardStatus.cancelled);
    });

    test('sửa tên và số tiền ngay trên thẻ; số tiền không hợp lệ và tên trống bị bỏ qua', () async {
      final c = controller(goalJson(nameIsDefault: true, name: 'Mục tiêu tiết kiệm'));
      await c.send('đặt mục tiêu tiết kiệm 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      c.updateGoal(id, name: 'Quỹ du lịch', targetCents: BigInt.from(30000000));
      c.updateGoal(id, name: '  ', targetCents: BigInt.zero);

      final goal = c.state.messages.whereType<GoalDraftCard>().single.goal;
      expect((goal.name, goal.nameIsDefault, goal.targetCents), ('Quỹ du lịch', false, BigInt.from(30000000)));
    });

    test('thêm hạn bằng tay rồi bỏ hạn: không hạn vẫn tạo được', () async {
      final c = controller(goalJson(deadline: null, deadlineText: null));
      await c.send('đặt mục tiêu tiết kiệm 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      c.updateGoal(id, deadline: DateTime.now().add(const Duration(days: 40)));
      expect(c.state.messages.whereType<GoalDraftCard>().single.goal.deadline, isNotNull);
      c.updateGoal(id, clearDeadline: true);
      await c.confirmGoal(id);

      expect(created.single.$3, isNull);
    });

    test('hạn đã qua (người dùng để thẻ lâu rồi mới bấm): không tạo, báo chọn lại ngày', () async {
      final c = controller(goalJson(deadline: DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String()));
      await c.send('đặt mục tiêu mua xe máy 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      await c.confirmGoal(id);

      expect(created, isEmpty);
      expect(c.state.messages.whereType<GoalDraftCard>().single.error, contains('tương lai'));
    });

    test('app không có hàm tạo mục tiêu thì bấm Tạo không làm gì (không giả vờ đã tạo)', () async {
      final c = controller(goalJson(), withCreate: false);
      await c.send('đặt mục tiêu mua xe máy 50 triệu');
      final id = c.state.messages.whereType<GoalDraftCard>().single.id;

      await c.confirmGoal(id);

      expect(c.state.messages.whereType<GoalDraftCard>().single.status, GoalCardStatus.pending);
    });
  });

  group('thẻ trên màn hình', () {
    Future<AssistantController> pump(WidgetTester tester, Map<String, dynamic> reply) async {
      final c = controller(reply);
      await c.send('đặt mục tiêu mua xe máy 50 triệu');
      await tester.pumpWidget(ProviderScope(
        overrides: [assistantControllerProvider.overrideWith((ref) => c)],
        child: Consumer(builder: (context, ref, _) {
          final card = ref.watch(assistantControllerProvider).messages.whereType<GoalDraftCard>().single;
          return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GoalDraftCardView(card: card))));
        }),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('hiện tên, số tiền, ngày hạn cụ thể kèm cụm đã nói và số cần dành mỗi tháng', (tester) async {
      final due = DateTime.now().add(const Duration(days: 62));
      await pump(tester, goalJson(deadline: due.toUtc().toIso8601String()));

      expect(find.byKey(const ValueKey('goal-name-text')), findsOneWidget);
      expect(find.text('Mua xe máy'), findsOneWidget);
      expect(find.text('50.000.000 ₫'), findsOneWidget);
      final day = '${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}/${due.year}';
      expect(find.text('Hạn: $day (2 tháng sau)'), findsOneWidget);
      expect(find.textContaining('Cần ~'), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-create')), findsOneWidget);
    });

    testWidgets('không hạn: hiện "Chưa có hạn" và nút Thêm hạn, không có số mỗi tháng; tên mặc định có lời nhắc', (tester) async {
      await pump(tester, goalJson(deadline: null, deadlineText: null, nameIsDefault: true, name: 'Mục tiêu tiết kiệm'));

      expect(find.text('Chưa có hạn'), findsOneWidget);
      expect(find.text('Thêm hạn'), findsOneWidget);
      expect(find.textContaining('Cần ~'), findsNothing);
      expect(find.textContaining('đặt tên tạm'), findsOneWidget);
    });

    testWidgets('bấm Tạo mục tiêu: tạo một lần và thẻ thành dòng "Đã tạo mục tiêu"', (tester) async {
      await pump(tester, goalJson(deadline: DateTime.now().add(const Duration(days: 62)).toUtc().toIso8601String()));

      await tester.tap(find.byKey(const ValueKey('goal-create')));
      await tester.pumpAndSettle();

      expect(created, hasLength(1));
      expect(find.textContaining('Đã tạo mục tiêu "Mua xe máy"'), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-create')), findsNothing);
    });

    testWidgets('bấm Hủy: thẻ thành dòng đã hủy, không tạo gì', (tester) async {
      await pump(tester, goalJson());

      await tester.tap(find.byKey(const ValueKey('goal-cancel')));
      await tester.pumpAndSettle();

      expect(created, isEmpty);
      expect(find.textContaining('Đã hủy'), findsOneWidget);
    });

    testWidgets('Sửa: đổi tên và số tiền rồi thẻ cập nhật; số tiền sai thì báo lỗi và không đóng', (tester) async {
      await pump(tester, goalJson());

      await tester.tap(find.byKey(const ValueKey('goal-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('goal-amount')), 'abc');
      await tester.tap(find.byKey(const ValueKey('goal-edit-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('số tiền hợp lệ'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('goal-name')), 'Quỹ du lịch');
      await tester.enterText(find.byKey(const ValueKey('goal-amount')), '30000000');
      await tester.tap(find.byKey(const ValueKey('goal-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('Quỹ du lịch'), findsOneWidget);
      expect(find.text('30.000.000 ₫'), findsOneWidget);
    });
  });
}
