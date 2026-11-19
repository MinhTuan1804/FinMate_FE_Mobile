import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/agent_answer.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/chat_cards.dart';
import '../../fixtures/fixture.dart';

/// Hỏi AI Financial Agent (`POST /agent/ask`): thẻ trả lời có kết luận, "Vì sao?" và thẻ đề xuất. Agent chỉ đề xuất, người dùng bấm mới đặt hạn mức.
/// JSON có hình dạng đúng như `AgentAnswerDto` trong docs/agent-api.md.
const _answeredJson = {
  'status': 'answered',
  'message': null,
  'claims': [
    {'text': 'Bạn đang có 100.000.000 đồng.', 'evidenceIds': ['balance']},
  ],
  'evidence': [
    {
      'id': 'balance',
      'key': 'total_balance',
      'valueVnd': 100000000,
      'text': 'Tổng số dư các tài khoản',
      'unit': 'VND',
      'source': 'confirmed',
      'asOf': '2026-11-07T10:00:00+07:00',
      'confidence': 1.0,
      'sourceName': null,
      'sourceUrl': null,
    },
    {'id': 'doc', 'key': 'note', 'valueVnd': null, 'text': 'Đoạn tài liệu', 'unit': '', 'source': 'document', 'asOf': null, 'confidence': 0.857, 'sourceName': 'Cục Thống kê'},
  ],
  'verdict': 'tight',
  'traceId': '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
  'usedTemplate': false,
  'suggestedActions': [
    {'kind': 'set_budget_limit', 'title': 'Đặt hạn mức Ăn uống', 'amountVnd': 3000000, 'date': null, 'categorySlug': 'food', 'categoryName': 'Ăn uống', 'evidenceIds': ['balance']},
    {'kind': 'wait_until', 'title': 'Nên đợi', 'amountVnd': null, 'date': '2026-12-04', 'categorySlug': null, 'categoryName': null, 'evidenceIds': []},
  ],
};

class _Repo extends AssistantRepository {
  final Map<String, dynamic> answer;
  final Object? failWith;

  /// Phản hồi của chat (`POST /transactions/chat`) cho mọi câu: mặc định server gắn `ask_agent` (câu kế hoạch)
  final ChatReply chatReply;
  final List<String> asked = [];
  final List<String> chatted = [];
  final List<DateTime> reminders = [];
  final List<BigInt> checked = [];
  Object? reminderFails;

  @override
  Future<bool> schedulePurchaseReminder(DateTime date) async {
    if (reminderFails != null) throw reminderFails!;
    reminders.add(date);
    return true;
  }

  @override
  Future<PurchaseAssessment> purchaseCheck(PurchaseDraft draft) async {
    checked.add(draft.amountCents);
    return const PurchaseAssessment(verdict: 'fits_plan', summary: 'Hợp kế hoạch.');
  }

  _Repo(this.answer, {this.failWith, this.chatReply = const ChatReply(action: ChatAction.reply, intent: 'ask_agent')})
      : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async {
    chatted.add(text);
    return chatReply;
  }

  @override
  Future<VoiceReply> voiceChat(String filePath, {String? accountId, String? clientRequestId}) async =>
      VoiceReply(transcript: 'Nếu thu nhập giảm thì sao', chat: chatReply);

  @override
  Future<AgentAnswer> askAgent(String question) async {
    asked.add(question);
    if (failWith != null) throw failWith!;
    return AgentAnswer.fromJson(answer);
  }
}

/// Agent chỉ trả lời khi test cho phép, để quan sát trạng thái "đang chờ agent".
class _SlowRepo extends _Repo {
  final Completer<AgentAnswer> gate;

  _SlowRepo(this.gate) : super(_answeredJson);

  @override
  Future<AgentAnswer> askAgent(String question) => gate.future;
}

void main() {
  late List<(String, BigInt)> limits;
  late List<(String, BigInt, DateTime?)> createdGoals;
  late List<(String, DateTime)> changedDeadlines;
  Object? limitFails;
  Object? changeFails;

  AssistantController controller(_Repo repo, {bool withLimit = true}) => AssistantController(
        repository: repo,
        retryEvery: null,
        createGoal: (name, target, deadline) async {
          createdGoals.add((name, target, deadline));
          return 'goal-${createdGoals.length}';
        },
        changeGoalDeadline: (id, deadline) async {
          if (changeFails != null) throw changeFails!;
          changedDeadlines.add((id, deadline));
        },
        setBudgetLimit: withLimit
            ? (slug, cents) async {
                if (limitFails != null) throw limitFails!;
                limits.add((slug, cents));
              }
            : null,
      );

  setUp(() {
    limits = [];
    createdGoals = [];
    changedDeadlines = [];
    limitFails = null;
    changeFails = null;
  });

  group('đọc phản hồi', () {
    test('AgentAnswerDto thành câu trả lời: kết luận, mệnh đề, bằng chứng, thẻ đề xuất', () {
      final a = AgentAnswer.fromJson(_answeredJson);

      expect(a.isAnswered, isTrue);
      expect(a.verdict, 'tight');
      expect(a.claims.single.evidenceIds, ['balance']);
      expect(a.evidence, hasLength(2));
      expect(a.evidence.first.valueVnd, BigInt.from(100000000));
      expect(a.evidence.last.valueVnd, isNull, reason: 'bằng chứng chỉ là chữ không có số tiền');
      expect(a.evidenceById('balance')!.source, 'confirmed');
      expect(a.suggestedActions.first.canApply, isTrue);
      expect(a.suggestedActions.last.canApply, isTrue, reason: 'wait_until có ngày: nút "Nhắc tôi" hẹn đúng ngày đó');
      expect(const AgentSuggestedAction(kind: AgentSuggestedAction.waitUntil, title: 'Nên đợi').canApply, isFalse, reason: 'không có ngày thì không có gì để nhắc');
      expect(a.suggestedActions.last.date, DateTime(2026, 12, 4));
    });

    test('thiếu trường vẫn đọc được: không ném, trạng thái mặc định là thiếu dữ liệu', () {
      final a = AgentAnswer.fromJson(const {});

      expect(a.status, AgentAnswer.insufficientData);
      expect(a.claims, isEmpty);
      expect(a.suggestedActions, isEmpty);
    });
  });

  // Một ô nhập cho cả chat lẫn agent: chat luôn được hỏi trước; server gắn `ask_agent` cho câu kế hoạch và `out_of_scope` cho câu chat không hiểu.
  group('tự chuyển sang agent (không có công tắc)', () {
    test('câu kế hoạch (ask_agent): chỉ hỏi agent một lần, hiện MỘT thẻ, chat không ghi và không có lời đáp thừa', () async {
      final repo = _Repo(_answeredJson);
      final c = controller(repo);

      await c.send('Mua xe 600 triệu sau 2 năm được không?');

      expect(repo.chatted, ['Mua xe 600 triệu sau 2 năm được không?']);
      expect(repo.asked, ['Mua xe 600 triệu sau 2 năm được không?']);
      final m = c.state.messages;
      expect(m, hasLength(2));
      expect((m[0] as UserText).text, 'Mua xe 600 triệu sau 2 năm được không?');
      expect((m[1] as AgentCard).answer.verdict, 'tight');
      expect(c.state.isSending, isFalse);
    });

    test('trong lúc chờ agent: isAskingAgent bật (màn hình hiện dòng "có thể mất vài chục giây"), xong hoặc lỗi thì tắt', () async {
      final gate = Completer<AgentAnswer>();
      final c = controller(_SlowRepo(gate));

      final sending = c.send('Nếu mất việc tôi sống được bao lâu?');
      await Future<void>.delayed(Duration.zero);
      expect(c.state.isAskingAgent, isTrue);
      expect(c.state.isSending, isTrue);

      gate.complete(AgentAnswer.fromJson(_answeredJson));
      await sending;
      expect(c.state.isAskingAgent, isFalse);
      expect(c.state.isSending, isFalse);

      final failing = controller(_Repo(_answeredJson, failWith: StateError('lỗi')));
      await failing.send('Nếu mất việc tôi sống được bao lâu?');
      expect(failing.state.isAskingAgent, isFalse);
    });

    test('câu chat không hiểu (out_of_scope): agent trả lời thay, câu "chỉ giúp ghi chi tiêu" của chat không hiện', () async {
      final repo = _Repo(
        {'status': 'refused', 'message': 'Mình chỉ hỗ trợ tài chính cá nhân.', 'claims': [], 'evidence': [], 'suggestedActions': []},
        chatReply: const ChatReply(action: ChatAction.reply, intent: 'out_of_scope', replyText: 'Mình chỉ giúp ghi chi tiêu.'),
      );
      final c = controller(repo);

      await c.send('Lạm phát năm nay bao nhiêu?');

      expect(repo.asked, ['Lạm phát năm nay bao nhiêu?']);
      expect(c.state.messages.whereType<AssistantText>(), isEmpty);
      expect(c.state.messages.whereType<AgentCard>().single.answer.status, AgentAnswer.refused);
    });

    test('câu chat không hiểu mà agent lỗi: giữ lời đáp cũ của chat, không hiện lỗi', () async {
      final c = controller(_Repo(
        _answeredJson,
        failWith: NetworkException(),
        chatReply: const ChatReply(action: ChatAction.reply, intent: 'out_of_scope', replyText: 'Mình chỉ giúp ghi chi tiêu.'),
      ));

      await c.send('Thời tiết hôm nay thế nào');

      expect(c.state.messages.whereType<AgentCard>(), isEmpty);
      expect((c.state.messages.last as AssistantText).text, 'Mình chỉ giúp ghi chi tiêu.');
      expect(c.state.isSending, isFalse);
    });

    test('câu kế hoạch mà agent lỗi (429, 503...): hiện lỗi thành một dòng của trợ lý, không có thẻ', () async {
      final c = controller(_Repo(_answeredJson, failWith: NetworkException()));

      await c.send('Nếu thu nhập giảm 30% thì sao?');

      expect(c.state.messages.whereType<AgentCard>(), isEmpty);
      expect((c.state.messages.last as AssistantText).text, isNotEmpty);
      expect(c.state.isSending, isFalse);
    });

    test('câu thường (chào hỏi, ghi chép, đã có thẻ riêng) không đụng tới agent', () async {
      for (final intent in ['greet', 'ask_spending', 'evaluate_purchase', 'needs_amount']) {
        final repo = _Repo(_answeredJson, chatReply: ChatReply(action: ChatAction.reply, intent: intent, replyText: 'Lời của chat'));
        final c = controller(repo);

        await c.send('một câu bất kỳ');

        expect(repo.asked, isEmpty, reason: intent);
        expect((c.state.messages.last as AssistantText).text, 'Lời của chat', reason: intent);
      }
    });

    test('giọng nói: câu kế hoạch cũng chuyển sang agent, với chữ đã nhận dạng', () async {
      final repo = _Repo(_answeredJson);
      final c = controller(repo);

      await c.sendVoice('/tmp/x.m4a');

      expect(repo.asked, ['Nếu thu nhập giảm thì sao']);
      expect((c.state.messages.first as UserText).text, 'Nếu thu nhập giảm thì sao');
      expect(c.state.messages.whereType<AgentCard>(), hasLength(1));
    });
  });

  group('thẻ đề xuất', () {
    Future<(AssistantController, int)> asked() async {
      final c = controller(_Repo(_answeredJson));
      await c.send('Chia ngân sách giúp mình');
      return (c, c.state.messages.whereType<AgentCard>().single.id);
    }

    AgentCard card(AssistantController c) => c.state.messages.whereType<AgentCard>().single;

    test('bấm đặt hạn mức: gọi đúng nhóm và số tiền một lần, thẻ thành đã áp dụng', () async {
      final (c, id) = await asked();

      await c.applyAgentAction(id, 0);
      await c.applyAgentAction(id, 0); // bấm lại không làm gì thêm

      expect(limits, [('food', BigInt.from(3000000))]);
      expect(card(c).applied, {0});
      expect(card(c).applying, isNull);
      expect(card(c).error, isNull);
    });

    test('lỗi khi đặt hạn mức: giữ thẻ để bấm lại, kèm lý do', () async {
      final (c, id) = await asked();
      limitFails = StateError('Bạn chưa có nhóm này.');

      await c.applyAgentAction(id, 0);

      expect(card(c).applied, isEmpty);
      expect(card(c).error, 'Bạn chưa có nhóm này.');

      limitFails = null;
      await c.applyAgentAction(id, 0);
      expect(card(c).applied, {0});
      expect(card(c).error, isNull);
    });

    test('chỉ số ngoài phạm vi, hoặc loại thẻ app chưa biết (backend mới hơn), không gọi gì', () async {
      final repo = _Repo({
        ..._answeredJson,
        'suggestedActions': [
          {'kind': 'something_new', 'title': 'Loại mới', 'amountVnd': 1000, 'date': '2026-12-04', 'categorySlug': 'food'},
        ],
      });
      final c = controller(repo);
      await c.send('Chia ngân sách giúp mình');
      final id = card(c).id;

      await c.applyAgentAction(id, 0);
      await c.applyAgentAction(id, 7);

      expect(limits, isEmpty);
      expect(repo.reminders, isEmpty);
      expect(card(c).applied, isEmpty);
    });

    test('không có hàm đặt hạn mức thì thẻ không áp dụng được và không ném', () async {
      final c = controller(_Repo(_answeredJson), withLimit: false);
      await c.send('Chia ngân sách');

      await c.applyAgentAction(card(c).id, 0);

      expect(card(c).applied, isEmpty);
    });
  });

  group('đề xuất mở rộng: tạo mục tiêu, kiểm tra lại giá thấp hơn, nhắc ngày mua', () {
    final planJson = {
      ..._answeredJson,
      'suggestedActions': [
        {'kind': 'create_goal', 'title': 'Tạo mục tiêu tiết kiệm 600.000.000 đồng trong 24 tháng', 'amountVnd': 600000000, 'date': '2028-11-10'},
        {'kind': 'lower_amount_to', 'title': 'Giảm số tiền mua xuống tối đa 20.000.000 đồng', 'amountVnd': 20000000},
        {'kind': 'wait_until', 'title': 'Hoãn mua tới 04/12/2026', 'date': '2026-12-04'},
        {'kind': 'create_goal', 'title': 'Thiếu số tiền', 'date': '2028-11-10'}, // không đủ dữ liệu: không có nút
      ],
    };

    Future<(AssistantController, _Repo, int)> asked() async {
      final repo = _Repo(planJson);
      final c = controller(repo);
      await c.send('Mua xe 600 triệu sau 2 năm được không?');
      return (c, repo, c.state.messages.whereType<AgentCard>().single.id);
    }

    AgentCard card(AssistantController c) => c.state.messages.whereType<AgentCard>().single;

    test('tạo mục tiêu: người dùng đã bấm nút nên tạo luôn một lần với số tiền và hạn của agent (23:59:59), thẻ "Đã tạo" có id để hoàn tác', () async {
      final (c, _, id) = await asked();

      await c.applyAgentAction(id, 0);
      await c.applyAgentAction(id, 0); // bấm lại không tạo thêm

      expect(createdGoals, [('Mục tiêu tiết kiệm', BigInt.from(600000000), DateTime(2028, 11, 10, 23, 59, 59))]);
      final goal = c.state.messages.whereType<GoalDraftCard>().single;
      expect((goal.status, goal.goalId), (GoalCardStatus.created, 'goal-1'));
      expect(card(c).applied, {0});
    });

    test('đổi hạn mục tiêu (change_goal_deadline): gọi đúng id và hạn mới (23:59:59) một lần; lỗi thì giữ thẻ để bấm lại kèm lý do', () async {
      final repo = _Repo({
        ..._answeredJson,
        'suggestedActions': [
          {'kind': 'change_goal_deadline', 'title': 'Đổi hạn mục tiêu "Mua nhà" thành 5 năm', 'amountVnd': 8333334, 'date': '2031-11-10', 'targetId': 'goal-77'},
          {'kind': 'change_goal_deadline', 'title': 'Thiếu id', 'amountVnd': 1, 'date': '2031-11-10'},
        ],
      });
      final c = controller(repo);
      await c.send('Mục tiêu nhà có khả thi không');
      final id = card(c).id;
      changeFails = StateError('Không tìm thấy mục tiêu này.');

      await c.applyAgentAction(id, 0);
      expect(card(c).applied, isEmpty);
      expect(card(c).error, 'Không tìm thấy mục tiêu này.');

      changeFails = null;
      await c.applyAgentAction(id, 0);
      await c.applyAgentAction(id, 0);
      await c.applyAgentAction(id, 1); // không có id: không có nút, không làm gì

      expect(changedDeadlines, [('goal-77', DateTime(2031, 11, 10, 23, 59, 59))]);
      expect(card(c).applied, {0});
      expect(card(c).answer.suggestedActions[1].canApply, isFalse);
      expect(card(c).answer.suggestedActions[0].applyLabel, 'Đổi hạn');
    });

    test('kiểm tra lại với giá thấp hơn: thêm thẻ mua với giá đó và gọi đánh giá, chỉ đọc', () async {
      final (c, repo, id) = await asked();

      await c.applyAgentAction(id, 1);
      await Future<void>.delayed(Duration.zero);

      final purchase = c.state.messages.whereType<PurchaseCard>().single;
      expect(purchase.purchase.amountCents, BigInt.from(20000000));
      expect(repo.checked, [BigInt.from(20000000)]);
      expect(c.state.messages.whereType<PurchaseCard>().single.status, PurchaseCardStatus.assessed);
      expect(card(c).applied, {1});
    });

    test('nhắc tôi (wait_until): hẹn đúng ngày một lần; lỗi (ngày không hợp lệ) giữ thẻ để bấm lại, kèm lý do', () async {
      final (c, repo, id) = await asked();
      repo.reminderFails = StateError('Ngày nhắc phải sau hôm nay.');

      await c.applyAgentAction(id, 2);
      expect(card(c).applied, isEmpty);
      expect(card(c).error, 'Ngày nhắc phải sau hôm nay.');

      repo.reminderFails = null;
      await c.applyAgentAction(id, 2);
      await c.applyAgentAction(id, 2);

      expect(repo.reminders, [DateTime(2026, 12, 4)]);
      expect(card(c).applied, {2});
      expect(card(c).error, isNull);
    });

    test('thẻ thiếu dữ liệu cho việc của nó (create_goal không có số tiền) không có nút và không làm gì', () async {
      final (c, _, id) = await asked();

      await c.applyAgentAction(id, 3);

      expect(card(c).answer.suggestedActions[3].canApply, isFalse);
      expect(c.state.messages.whereType<GoalDraftCard>(), isEmpty);
    });

    testWidgets('trên màn hình: mỗi loại có nhãn nút riêng và nhãn "xong" riêng', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (c, _, _) = await asked();
      await tester.pumpWidget(ProviderScope(
        overrides: [assistantControllerProvider.overrideWith((ref) => c)],
        child: Consumer(builder: (context, ref, _) {
          final card = ref.watch(assistantControllerProvider).messages.whereType<AgentCard>().single;
          return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AgentCardView(card: card))));
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tạo mục tiêu'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
      expect(find.text('Nhắc tôi'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-action-3')), findsNothing, reason: 'thiếu số tiền: chỉ hiện chữ');

      await tester.tap(find.byKey(const ValueKey('agent-action-2')));
      await tester.pumpAndSettle();

      expect(find.text('Đã hẹn'), findsOneWidget);
      expect(find.text('Nhắc tôi'), findsNothing);
    });
  });

  group('thẻ trên màn hình', () {
    Future<AssistantController> pump(WidgetTester tester, Map<String, dynamic> answer) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = controller(_Repo(answer));
      await c.send('Hỏi gì đó');
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(), // vòng lặp bơm nhiều lần: không dùng key thì ProviderScope cũ giữ lại bộ điều khiển đầu tiên
        overrides: [assistantControllerProvider.overrideWith((ref) => c)],
        child: Consumer(builder: (context, ref, _) {
          final card = ref.watch(assistantControllerProvider).messages.whereType<AgentCard>().single;
          return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AgentCardView(card: card))));
        }),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('hiện kết luận, mệnh đề và dòng cảnh báo; "Vì sao?" mở ra nguồn, ngày và độ tin cậy (không phần trăm)', (tester) async {
      await pump(tester, _answeredJson);

      expect(find.byKey(const ValueKey('agent-verdict')), findsOneWidget);
      expect(find.text('Cần cân nhắc'), findsOneWidget);
      expect(find.text('Bạn đang có 100.000.000 đồng.'), findsOneWidget);
      expect(find.textContaining('không đưa lời khuyên đầu tư'), findsOneWidget);
      expect(find.text('Tổng số dư các tài khoản'), findsNothing, reason: 'bằng chứng chỉ hiện khi mở "Vì sao?"');

      await tester.tap(find.byKey(const ValueKey('agent-why')));
      await tester.pumpAndSettle();

      expect(find.text('Tổng số dư các tài khoản'), findsOneWidget);
      expect(find.text('100.000.000 ₫'), findsOneWidget);
      expect(find.textContaining('đã xác nhận · 07/11/2026 · độ tin cậy 1,00'), findsOneWidget);
      expect(find.textContaining('theo tài liệu · Cục Thống kê · độ tin cậy 0,86'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('bấm Đặt hạn mức: gọi hàm đặt hạn mức rồi hiện "Đã đặt"; thẻ wait_until có nút "Nhắc tôi"', (tester) async {
      await pump(tester, _answeredJson);

      expect(find.byKey(const ValueKey('agent-action-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-action-1')), findsOneWidget);
      expect(find.text('Nhắc tôi'), findsOneWidget);
      expect(find.textContaining('Nên đợi'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-action-0')));
      await tester.pumpAndSettle();

      expect(limits, [('food', BigInt.from(3000000))]);
      expect(find.text('Đã đặt'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-action-0')), findsNothing);
    });

    testWidgets('đánh giá mục tiêu: hai con số chính to rõ (cần góp / dành được, % thu nhập), không còn đoạn văn dài; phương án gọn, không lặp số tiền; ghi chú sơ bộ chỉ một lần', (tester) async {
      Map<String, dynamic> ev(String id, int? value, String text) =>
          {'id': id, 'key': id, 'valueVnd': value, 'text': text, 'unit': value == null ? 'label' : 'VND', 'source': 'estimated', 'asOf': '2026-11-19T10:00:00+07:00', 'confidence': 0.5};
      final goal = {
        'status': 'answered',
        'message': null,
        'claims': [{'text': 'ĐOẠN VĂN DÀI KHÔNG ĐƯỢC HIỆN', 'evidenceIds': ['plan_required']}],
        'evidence': [
          ev('goal_target', 500000000, 'Số tiền mục tiêu'),
          ev('plan_required', 13513514, 'Cần góp mỗi tháng'),
          ev('income_declared', 10000000, 'Thu nhập đã khai'),
          ev('capacity_base', 10000000, 'Khả năng góp'),
          ev('prelim_note', null, 'Chỉ để tham khảo: mới dựa trên thu nhập bạn khai. Ghi chép chi tiêu thật (≥ 3 tháng) để mình tính chính xác hơn.'),
        ],
        'verdict': 'infeasible',
        'suggestedActions': [
          {'kind': 'change_goal_deadline', 'title': 'Kéo dài thành 4 năm 1 tháng · góp 10.204.082 đồng/tháng', 'amountVnd': 10204082, 'date': '2030-12-19', 'targetId': 'g1'},
        ],
      };
      await pump(tester, goal);

      expect(find.text('Khó đạt'), findsOneWidget);
      expect(find.text('13.513.514 ₫'), findsOneWidget);
      expect(find.text('bằng 135% thu nhập bạn khai'), findsOneWidget);
      expect(find.text('10.000.000 ₫'), findsOneWidget);
      expect(find.textContaining('ĐOẠN VĂN DÀI'), findsNothing);
      expect(find.text('Kéo dài thành 4 năm 1 tháng · góp 10.204.082 đồng/tháng'), findsOneWidget, reason: 'tiêu đề nguyên văn, không ghép thêm số tiền/ngày');
      expect(find.textContaining('10.204.082 ₫'), findsNothing);
      expect(find.text('Nếu muốn dễ thở hơn'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-preliminary-note')), findsOneWidget);
      expect(find.textContaining('Dải dự báo, chỉ để tham khảo'), findsNothing, reason: 'ghi chú sơ bộ đã nói rồi: không lặp lại');
    });

    testWidgets('ước tính sơ bộ: ghi chú "chỉ để tham khảo" của backend hiện cố định dưới thẻ; số liệu dựa trên dữ liệu thật thì không có ghi chú', (tester) async {
      final prelim = {
        ..._answeredJson,
        'evidence': [
          ...(_answeredJson['evidence'] as List),
          {
            'id': 'prelim_note',
            'key': 'goal_plan_preliminary',
            'valueVnd': null,
            'text': 'Số liệu này chỉ để tham khảo: mình mới phân tích dựa trên thu nhập bạn đã khai, chưa có chi tiêu thực tế.',
            'unit': 'label',
            'source': 'estimated',
            'asOf': '2026-11-19T10:00:00+07:00',
            'confidence': 0.2,
          },
        ],
      };
      await pump(tester, prelim);
      expect(find.byKey(const ValueKey('agent-preliminary-note')), findsOneWidget);
      expect(find.textContaining('chưa có chi tiêu thực tế'), findsOneWidget);

      await pump(tester, _answeredJson);
      expect(find.byKey(const ValueKey('agent-preliminary-note')), findsNothing);
    });

    testWidgets('không có câu trả lời (từ chối, hỏi lại, thiếu dữ liệu): chỉ hiện lời nhắn của backend', (tester) async {
      for (final status in ['refused', 'clarify', 'insufficient_data']) {
        await pump(tester, {'status': status, 'message': 'Lời nhắn của $status', 'claims': [], 'evidence': [], 'suggestedActions': []});

        expect(find.text('Lời nhắn của $status'), findsOneWidget);
        expect(find.byKey(const ValueKey('agent-verdict')), findsNothing);
        expect(find.byKey(const ValueKey('agent-why')), findsNothing);
      }
    });
  });
}
