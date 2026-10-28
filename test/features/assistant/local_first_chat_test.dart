import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'dart:convert';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/draft_saver.dart';
import 'package:finmate/features/assistant/data/local_chat_decider.dart';
import 'package:finmate/features/assistant/data/local_first_chat.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../../fixtures/fixture.dart';

/// Repository giả: trả phản hồi `analyze` thật đã chụp; đếm xem đường nào được gọi.
class _Repo extends AssistantRepository {
  final List<String> analyzed = [];
  final List<String> voiced = [];
  final List<String> chatted = [];
  Object? analyzeError;
  ChatReply? chatReply;
  String fixtureName = 'chat_analyze_single';
  ChatAnalysis? forced;

  _Repo() : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  ChatAnalysis get _analysis => forced ?? ChatAnalysis.fromJson(fixtureData(fixtureName) as Map<String, dynamic>);

  @override
  Future<ChatAnalysis> analyze(String text) async {
    analyzed.add(text);
    if (analyzeError != null) {
      final e = analyzeError!;
      analyzeError = null;
      throw e;
    }
    return _analysis;
  }

  @override
  Future<VoiceAnalysis> analyzeVoice(String filePath) async {
    voiced.add(filePath);
    return VoiceAnalysis(transcript: 'ăn phở 45k', analysis: _analysis);
  }

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async {
    chatted.add(text);
    return chatReply ?? ChatReply.fromJson(fixtureData('chat_summary') as Map<String, dynamic>);
  }
}

void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late _Repo repo;

  LocalFirstChat localChat() => LocalFirstChat(
        decider: LocalChatDecider(db: db),
        saver: DraftSaver(
          categoryIdOf: (slug) => 'cat-$slug',
          saveAll: (items) async => throw StateError('không dùng trong test này'),
          syncNow: () async {},
          save: (draft, {required categoryId, required accountId, required clientRequestId}) => transactions.createTransaction(
          accountId: accountId,
          categoryId: categoryId,
          amountCents: draft.amountCents!,
          type: draft.type!,
          merchantName: draft.merchantName,
          description: draft.description ?? '',
          date: draft.transactedAt ?? DateTime(2026, 10, 13, 12),
          source: draft.source.apiValue,
          clientRequestId: clientRequestId,
          ),
        ),
        remember: (merchant, description, slug) => db.rememberCategory(merchantKey: memoryKey(merchant), itemKey: memoryKey(description), categorySlug: slug),
      );

  AssistantController controller({bool local = true}) {
    final c = AssistantController(repository: repo, local: local ? localChat() : null);
    c.selectAccount('acc-1');
    return c;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Mất mạng: giao dịch ghi ở máy và xếp hàng đồng bộ
    transactions = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);
    repo = _Repo();
  });
  tearDown(() => db.close());

  test('local_save_writes_row_and_queue_item: ghi ngay ở máy rồi xếp hàng đồng bộ, không cần server', () async {
    final c = controller();

    await c.send('ăn phở 45k');

    expect(repo.analyzed, ['ăn phở 45k']);
    expect(repo.chatted, isEmpty);
    final card = c.state.messages.whereType<SavedCard>().single;
    expect(card.tx.amountCents, BigInt.from(45000));
    final rows = await db.getAllTransactions();
    expect(rows.single.categoryId, 'cat-food');
    expect(rows.single.financialAccountId, 'acc-1');
    expect(await db.pendingSyncCount(), 1);
  });

  test('replay_does_not_duplicate: gửi lại sau lỗi dùng đúng mã yêu cầu cũ nên chỉ có một dòng', () async {
    repo.analyzeError = Exception('mất mạng');
    final c = controller();

    await c.send('ăn phở 45k');
    final error = c.state.messages.whereType<ErrorNote>().single;
    await c.retry(error.id);
    await c.retry(c.state.messages.whereType<ErrorNote>().firstOrNull?.id ?? -1); // đã hết thẻ lỗi: không làm gì

    expect((await db.getAllTransactions()).length, 1);
    expect(await db.pendingSyncCount(), 1);
    expect(c.state.messages.whereType<SavedCard>(), hasLength(1));
  });

  test('nhiều khoản: lời báo, MỘT thẻ gộp và các ghi chú; không ghi gì', () async {
    repo.fixtureName = 'chat_analyze_multi';
    final c = controller();

    await c.send('ăn phở 40k và đổ xăng 70k tổng cộng 100k');

    final kinds = c.state.messages.map((m) => m.runtimeType).toList();
    expect(kinds, [UserText, AssistantText, DraftBatchCard, AssistantText]);
    expect((c.state.messages.last as AssistantText).text, contains('100.000'));
    expect(await db.getAllTransactions(), isEmpty);
    expect(c.state.messages.whereType<DraftBatchCard>().single.drafts.every((d) => d.source == DraftSource.chat), isTrue);
  });

  test('khoản đã gộp: lời báo gộp của server hiện ra cả khi chỉ còn một nháp', () async {
    repo.forced = ChatAnalysis.fromJson({
      'intent': 'add_expense',
      'replyText': 'Mình gộp 2 khoản cùng danh mục lại cho gọn, bạn kiểm tra giúp mình nhé.',
      'entries': [
        {'kind': 'expense', 'amountCents': 35000, 'description': 'ăn cơm, uống nước', 'categorySlug': 'food', 'categorySource': 'rule', 'autoSaveOk': false, 'toOthers': false}
      ],
    });
    final c = controller();

    await c.send('ăn cơm 25k uống nước 10k');

    expect(c.state.messages.whereType<AssistantText>().map((m) => m.text), ['Mình gộp 2 khoản cùng danh mục lại cho gọn, bạn kiểm tra giúp mình nhé.']);
    expect(c.state.messages.whereType<DraftCard>().single.draft.amountCents, BigInt.from(35000));
    expect(await db.getAllTransactions(), isEmpty);
  });

  test('câu hỏi tổng vẫn đi đường server (chat), không đoán từ dữ liệu máy chưa đủ', () async {
    repo.forced = const ChatAnalysis(intent: 'ask_spending', hasQuery: true);
    final c = controller();

    await c.send('tháng này tôi tiêu bao nhiêu');

    expect(repo.chatted, ['tháng này tôi tiêu bao nhiêu']);
    expect(c.state.messages.whereType<SummaryCard>(), hasLength(1));
  });

  test('voice_uses_analyze_voice_when_flag_on: câu nghe được hiện ra và khoản lưu với nguồn Voice', () async {
    final c = controller();

    await c.sendVoice('v.m4a');

    expect(repo.voiced, ['v.m4a']);
    expect((c.state.messages.first as UserText).text, 'ăn phở 45k');
    expect(c.state.messages.whereType<SavedCard>(), hasLength(1));
    expect((await db.getAllTransactions()).single.id, startsWith('local-'));
  });

  test('flag_off_uses_old_path: không có local thì chat đi đường cũ qua server', () async {
    final c = controller(local: false);

    await c.send('ăn phở 45k');

    expect(repo.chatted, ['ăn phở 45k']);
    expect(repo.analyzed, isEmpty);
  });

  test('confirming_draft_updates_memory: xác nhận nháp ghi nhớ danh mục người dùng chọn', () async {
    repo.forced = ChatAnalysis.fromJson({
      'intent': 'add_expense',
      'entries': [
        {'kind': 'expense', 'amountCents': 30000, 'description': 'cà phê hạt', 'autoSaveOk': false, 'toOthers': false}
      ],
    });
    final c = controller();
    await c.send('cà phê hạt 30k');
    final card = c.state.messages.whereType<DraftCard>().single;

    c.resolveDraft(card.id, 'Đã ghi', categorySlug: 'shopping');
    await pumpEventQueue();

    final memory = await db.categoryMemory('', 'ca phe hat');
    expect((memory!.categorySlug, memory.confirmCount), ('shopping', 1));
  });

  test('save_with_the_same_request_id_twice_keeps_one_row_and_one_queue_item', () async {
    final draft = DraftTransaction(amountCents: BigInt.from(45000), type: TransactionType.expense, description: 'ăn phở', transactedAt: DateTime(2026, 10, 13, 12));
    final chat = localChat();

    await chat.saver.save(draft, categoryId: 'cat-food', accountId: 'acc-1', clientRequestId: 'same-id');
    await chat.saver.save(draft, categoryId: 'cat-food', accountId: 'acc-1', clientRequestId: 'same-id');

    expect((await db.getAllTransactions()).length, 1);
    expect(await db.pendingSyncCount(), 1);
  });

  test('offline_save_survives_and_syncs_later: ghi ở máy khi mất mạng rồi đồng bộ đúng một lần khi có mạng', () async {
    final c = controller();
    await c.send('ăn phở 45k');
    final queued = (await db.getPendingSyncItems()).single;
    final sentId = (jsonDecode(queued.payload) as Map)['clientRequestId'];
    final server = (fixtureData('transactions') as List)[2];
    final online = RouteAdapter((o) => respondJson({'success': true, 'data': server}));
    final sync = SyncService(db: db, apiClient: testApiClient(online));

    expect(await sync.processQueue(), 1);
    expect(await sync.processQueue(), 0); // hàng đợi đã trống: không gửi lại

    expect(online.requests, hasLength(1));
    expect((online.requests.single.data as Map)['clientRequestId'], sentId);
    expect(await db.pendingSyncCount(), 0);
    expect((await db.getAllTransactions()).single.id, server['id']);
  });

  test('đường cũ: lời nhắn của server hiện ra cả khi chỉ có một nháp (vế bị bỏ, tổng không khớp)', () async {
    repo.chatReply = ChatReply.fromJson({
      'action': 'confirm',
      'intent': 'add_expense',
      'replyText': 'Mình chưa thấy số tiền cho "cà phê" nên chưa ghi.',
      'draft': {'kind': 'expense', 'amountCents': 40000, 'transactionType': 'debit', 'description': 'ăn phở', 'categorySlug': 'food', 'missingFields': <String>[]},
    });
    final c = controller(local: false);

    await c.send('ăn phở 40k và cà phê');

    final texts = c.state.messages.whereType<AssistantText>().map((m) => m.text);
    expect(texts, ['Mình chưa thấy số tiền cho "cà phê" nên chưa ghi.']);
    expect(c.state.messages.whereType<DraftCard>(), hasLength(1));
  });
}
