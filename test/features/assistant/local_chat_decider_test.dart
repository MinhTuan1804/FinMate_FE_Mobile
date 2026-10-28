import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/assistant/data/local_chat_decider.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../../fixtures/fixture.dart';

/// Các ca dưới đây dùng phản hồi THẬT của `POST /api/v1/chat/analyze` (Rasa v5 + ai-service mới + backend), chụp 2026-10-13.
ChatAnalysis fixture(String name) => ChatAnalysis.fromJson(fixtureData(name) as Map<String, dynamic>);

void main() {
  late AppDatabase db;
  late LocalChatDecider decider;
  final now = DateTime(2026, 10, 13, 12, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    decider = LocalChatDecider(db: db);
  });
  tearDown(() => db.close());

  Future<void> insertDebit(int cents, DateTime at, {String id = 'tx-1'}) => db.insertLocalTransaction(LocalTransactionsCompanion.insert(
        id: id,
        clientRequestId: 'req-$id',
        amountCents: BigInt.from(cents),
        transactionType: 'Debit',
        status: 'Confirmed',
        financialAccountId: 'acc-1',
        transactedAt: at,
      ));

  group('đọc phản hồi analyze', () {
    test('đủ các trường mới: nguồn danh mục, tổng đã nói, vế bị bỏ', () {
      final multi = fixture('chat_analyze_multi');
      expect(multi.entries.map((e) => e.amountCents), [BigInt.from(40000), BigInt.from(70000)]);
      expect(multi.entries.every((e) => e.categorySource == 'rule'), isTrue);
      expect((multi.totalAmount, multi.totalMismatch), (100000, true));
      expect(fixture('chat_analyze_skipped').skipped, ['cà phê']);
    });

    test('app_tolerates_missing_category_source: server cũ không có các trường mới', () {
      final old = ChatAnalysis.fromJson({
        'intent': 'add_expense',
        'entry': {'kind': 'expense', 'amountCents': 45000, 'categorySlug': 'food', 'autoSaveOk': true, 'toOthers': false},
        'entries': [
          {'kind': 'expense', 'amountCents': 45000, 'categorySlug': 'food', 'autoSaveOk': true, 'toOthers': false}
        ],
      });
      expect(old.entries.single.categorySource, isNull);
      expect(old.skipped, isEmpty);
      expect((old.totalAmount, old.totalMismatch), (null, false));
    });
  });

  group('đặt mục tiêu tiết kiệm', () {
    test('phản hồi analyze có goal: luôn là GoalDecision (thẻ xác nhận), không ghi giao dịch nào', () async {
      final analysis = ChatAnalysis.fromJson({
        'intent': 'create_goal',
        'replyText': 'Mình hiểu mục tiêu của bạn như thế này.',
        'goal': {'name': 'Mua xe máy', 'nameIsDefault': false, 'targetCents': 50000000, 'deadline': null, 'deadlineText': null},
      });

      final d = await decider.decide(analysis, accountId: 'acc-1', now: now);

      expect(d, isA<GoalDecision>());
      expect((d as GoalDecision).goal.targetCents, BigInt.from(50000000));
      expect(d.replyText, contains('mục tiêu'));
    });

    test('đang hỏi lại (không có goal) chỉ là câu trả lời', () async {
      final d = await decider.decide(
        ChatAnalysis.fromJson({'intent': 'create_goal', 'replyText': 'Bạn muốn tiết kiệm bao nhiêu?'}),
        accountId: 'acc-1',
        now: now,
      );

      expect(d, isA<Reply>());
      expect((d as Reply).text, contains('bao nhiêu'));
    });
  });

  group('quyết định ở máy', () {
    test('single_confident_expense_saves_now', () async {
      final d = await decider.decide(fixture('chat_analyze_single'), accountId: 'acc-1', now: now);

      expect(d, isA<SaveNow>());
      final draft = (d as SaveNow).draft;
      expect((draft.amountCents, draft.categorySlug, draft.type), (BigInt.from(45000), 'food', TransactionType.expense));
    });

    test('không có ví thì chỉ là nháp thiếu ví, không ghi ngay', () async {
      final d = await decider.decide(fixture('chat_analyze_single'), accountId: null, now: now);

      expect(d, isA<Drafts>());
      expect((d as Drafts).drafts.single.missingFields, ['account']);
    });

    test('multi_always_drafts: nhiều khoản không bao giờ ghi ngay', () async {
      final d = await decider.decide(fixture('chat_analyze_multi'), accountId: 'acc-1', now: now);

      expect(d, isA<Drafts>());
      expect((d as Drafts).drafts.map((x) => x.amountCents), [BigInt.from(40000), BigInt.from(70000)]);
      expect(d.drafts.every((x) => x.suggestedAccountId == 'acc-1'), isTrue);
    });

    test('duplicate_within_10_minutes_asks: cùng số tiền trong 10 phút thì hỏi, kèm mã giao dịch có thể trùng', () async {
      await insertDebit(45000, now.subtract(const Duration(minutes: 6)));

      final d = await decider.decide(fixture('chat_analyze_single'), accountId: 'acc-1', now: now);

      expect(d, isA<Drafts>());
      expect((d as Drafts).duplicateOf, {0: 'tx-1'});
      expect(d.drafts.single.possibleDuplicateId, 'tx-1');
    });

    test('cùng số tiền nhưng cách 11 phút thì không coi là trùng', () async {
      await insertDebit(45000, now.subtract(const Duration(minutes: 11)));

      expect(await decider.decide(fixture('chat_analyze_single'), accountId: 'acc-1', now: now), isA<SaveNow>());
    });

    test('skipped_clause_adds_reply_note: vế thiếu tiền được báo lại', () async {
      final d = await decider.decide(fixture('chat_analyze_skipped'), accountId: 'acc-1', now: now);

      expect(d, isA<Drafts>()); // server đã chặn ghi ngay khi có vế bị bỏ
      expect(d.notes.single, allOf(contains('cà phê'), contains('số tiền')));
    });

    test('total_mismatch_adds_warning: tổng đã nói khác tổng các khoản', () async {
      final d = await decider.decide(fixture('chat_analyze_multi'), accountId: 'acc-1', now: now);

      expect(d.notes.single, allOf(contains('100.000'), contains('110.000')));
    });

    test('tổng đã nói không khớp thì không ghi ngay dù server báo autoSaveOk', () async {
      final analysis = ChatAnalysis.fromJson({
        'intent': 'add_expense',
        'totalAmount': 200000,
        'totalMismatch': true,
        'entries': [
          {'kind': 'expense', 'amountCents': 50000, 'description': 'ăn trưa', 'categorySlug': 'food', 'categorySource': 'rule', 'autoSaveOk': true, 'toOthers': false}
        ],
      });

      expect(await decider.decide(analysis, accountId: 'acc-1', now: now), isA<Drafts>());
    });

    test('còn vế bị bỏ vì thiếu tiền thì không ghi ngay dù server báo autoSaveOk', () async {
      final analysis = ChatAnalysis.fromJson({
        'intent': 'add_expense',
        'skipped': ['cà phê'],
        'entries': [
          {'kind': 'expense', 'amountCents': 40000, 'description': 'ăn phở', 'categorySlug': 'food', 'categorySource': 'rule', 'autoSaveOk': true, 'toOthers': false}
        ],
      });

      expect(await decider.decide(analysis, accountId: 'acc-1', now: now), isA<Drafts>());
    });

    test('câu hỏi tổng đi đường server; câu chào chỉ là trả lời chữ', () async {
      final summary = ChatAnalysis.fromJson({'intent': 'ask_spending', 'query': {'metric': 'expense', 'periodLabel': 'tháng này'}});
      final greet = ChatAnalysis.fromJson({'intent': 'greet', 'replyText': 'Chào bạn!'});

      expect(await decider.decide(summary, accountId: 'acc-1', now: now), isA<NeedSummary>());
      final reply = await decider.decide(greet, accountId: 'acc-1', now: now);
      expect((reply as Reply).text, 'Chào bạn!');
    });
  });

  group('bộ nhớ riêng thắng nguồn yếu', () {
    ChatAnalysis single({required String? source, String slug = 'food'}) => ChatAnalysis.fromJson({
          'intent': 'add_expense',
          'entries': [
            {'kind': 'expense', 'amountCents': 30000, 'description': 'cà phê hạt', 'categorySlug': slug, 'categorySource': source, 'autoSaveOk': false, 'toOthers': false}
          ],
        });

    test('memory_overrides_cache_source: bộ nhớ riêng thắng gợi ý từ bảng nhớ chung', () async {
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');

      final d = await decider.decide(single(source: 'cache'), accountId: 'acc-1', now: now);

      expect((d as Drafts).drafts.single.categorySlug, 'shopping');
    });

    test('memory_overrides_rule_only_after_two_confirmations', () async {
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');
      var d = await decider.decide(single(source: 'rule'), accountId: 'acc-1', now: now);
      expect((d as Drafts).drafts.single.categorySlug, 'food'); // mới một lần xác nhận: luật vẫn thắng

      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');
      d = await decider.decide(single(source: 'rule'), accountId: 'acc-1', now: now);
      expect((d as Drafts).drafts.single.categorySlug, 'shopping');
    });

    test('bộ nhớ điền được món mà server chưa biết danh mục', () async {
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');

      final d = await decider.decide(single(source: null, slug: ''), accountId: 'acc-1', now: now);

      expect((d as Drafts).drafts.single.categorySlug, 'shopping');
    });
  });
}
