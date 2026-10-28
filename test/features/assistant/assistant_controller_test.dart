import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

/// Adapter có thể giữ phản hồi lại (để kiểm tra gửi đồng thời) và chọn fixture theo nội dung tin nhắn
class _ChatAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Completer<void>? gate;
  bool failNext = false;

  String fixtureFor(String text) {
    if (text.contains('cafe')) return 'chat_saved';
    if (text.contains('tieu bao nhieu')) return 'chat_summary';
    if (text.contains('xin chao')) return 'chat_reply_out_of_scope';
    if (text.contains('luong')) return 'chat_confirm_expense';
    if (text.contains('nhieu khoan')) return 'chat_confirm_multi';
    return 'chat_reply_needs_amount';
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (gate != null) await gate!.future;
    if (failNext) {
      failNext = false;
      throwNetworkDown(options);
    }
    final text = (options.data as Map)['text'] as String;
    if (text == 'ky la') return respondJson({'success': true, 'data': {'action': 'dance'}});
    return respondFixture(fixtureFor(text));
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _ChatAdapter adapter;
  late int dataChanged;
  late AssistantController controller;

  setUp(() {
    adapter = _ChatAdapter();
    dataChanged = 0;
    controller = AssistantController(
      repository: AssistantRepository(apiClient: testApiClient(adapter)),
      onDataChanged: () => dataChanged++,
    );
  });

  test('saved: thêm tin nhắn người dùng và thẻ đã ghi, làm mới dữ liệu một lần', () async {
    await controller.send('cafe highlands 55k');

    final m = controller.state.messages;
    expect(m, hasLength(2));
    expect((m[0] as UserText).text, 'cafe highlands 55k');
    expect((m[1] as SavedCard).tx.amountCents, BigInt.from(55000));
    expect(dataChanged, 1);
    expect(controller.state.isSending, isFalse);
  });

  test('summary và reply tạo thẻ tương ứng, không làm mới dữ liệu', () async {
    await controller.send('thang nay toi tieu bao nhieu');
    await controller.send('xin chao');

    final m = controller.state.messages;
    expect(m.whereType<SummaryCard>().single.summary.items, isNotEmpty);
    expect(m.whereType<AssistantText>().single.text, isNotEmpty);
    expect(dataChanged, 0);
  });

  test('confirm: thẻ nháp mang nguồn được truyền vào (giọng nói)', () async {
    await controller.send('luong 20 trieu', source: DraftSource.voice);

    final card = controller.state.messages.whereType<DraftCard>().single;
    expect(card.draft.source, DraftSource.voice);
    expect(card.draft.missingFields, ['category']);
    expect(card.resolved, isFalse);
  });

  test('chuỗi rỗng hoặc chỉ khoảng trắng không được gửi', () async {
    await controller.send('');
    await controller.send('   ');

    expect(controller.state.messages, isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('đang gửi thì bỏ qua tin nhắn thứ hai (chống gửi trùng)', () async {
    adapter.gate = Completer<void>();

    final first = controller.send('cafe 55k');
    await pumpEventQueue();
    expect(controller.state.isSending, isTrue);
    await controller.send('cafe 66k');

    expect(adapter.requests, hasLength(1));
    adapter.gate!.complete();
    await first;
    expect(controller.state.messages.whereType<UserText>(), hasLength(1));
  });

  test('lỗi mạng: ErrorNote kèm nội dung để gửi lại; gửi lại dùng cùng clientRequestId và thay thế ErrorNote', () async {
    adapter.failNext = true;
    await controller.send('cafe 55k');

    final note = controller.state.messages.whereType<ErrorNote>().single;
    expect(note.retryText, 'cafe 55k');
    expect(note.message, contains('kết nối'));

    await controller.retry(note.id);

    expect(adapter.requests, hasLength(2));
    final ids = adapter.requests.map((r) => (r.data as Map)['clientRequestId']).toList();
    expect(ids[0], isNotEmpty);
    expect(ids[1], ids[0]);
    expect(controller.state.messages.whereType<ErrorNote>(), isEmpty);
    expect(controller.state.messages.whereType<UserText>(), hasLength(1));
    expect(controller.state.messages.whereType<SavedCard>(), hasLength(1));
  });

  test('mỗi tin nhắn mới dùng clientRequestId khác nhau', () async {
    await controller.send('cafe 1k');
    await controller.send('cafe 2k');

    final ids = adapter.requests.map((r) => (r.data as Map)['clientRequestId']).toSet();
    expect(ids, hasLength(2));
  });

  test('phản hồi có action lạ: hiện thông điệp chung, không crash', () async {
    await controller.send('ky la');

    expect(controller.state.messages.last, isA<AssistantText>());
    expect((controller.state.messages.last as AssistantText).text, isNotEmpty);
  });

  test('chọn tài khoản được gửi kèm financialAccountId', () async {
    controller.selectAccount('acc-9');
    await controller.send('cafe 55k');

    expect((adapter.requests.single.data as Map)['financialAccountId'], 'acc-9');
  });

  test('addDraft thêm thẻ nháp; resolveDraft đánh dấu đã xử lý kèm tóm tắt', () async {
    controller.addDraft(const DraftTransaction(amountCents: null, source: DraftSource.receipt));
    final card = controller.state.messages.whereType<DraftCard>().single;

    controller.resolveDraft(card.id, 'Đã ghi: 55.000 ₫ · Ăn uống');

    final resolved = controller.state.messages.whereType<DraftCard>().single;
    expect(resolved.resolved, isTrue);
    expect(resolved.resolvedSummary, 'Đã ghi: 55.000 ₫ · Ăn uống');
    expect(resolved.draft.source, DraftSource.receipt);
  });

  test('provider tạo lại khi đổi người dùng: lịch sử chat cũ bị xóa', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final userId = StateProvider<String?>((ref) => 'u1');
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
      assistantRepositoryProvider.overrideWithValue(AssistantRepository(apiClient: testApiClient(adapter))),
      databaseProvider.overrideWithValue(db), // hàng chờ câu mất mạng nằm trong database của người dùng
    ]);
    addTearDown(container.dispose);
    container.listen(assistantControllerProvider, (_, __) {});

    await container.read(assistantControllerProvider.notifier).send('xin chao');
    expect(container.read(assistantControllerProvider).messages, isNotEmpty);

    container.read(userId.notifier).state = 'u2';
    await pumpEventQueue();

    expect(container.read(assistantControllerProvider).messages, isEmpty);
  });

  test('confirm nhiều khoản: một lời báo rồi MỘT thẻ gộp để xác nhận một lần, không ghi gì', () async {
    await controller.send('nhieu khoan');

    final m = controller.state.messages;
    expect(m.map((e) => e.runtimeType), [UserText, AssistantText, DraftBatchCard]);
    expect((m[1] as AssistantText).text, contains('3 khoản'));
    expect(m.whereType<DraftBatchCard>().single.drafts.map((d) => d.amountCents), [BigInt.from(20000), BigInt.from(10000), BigInt.from(50000)]);
    expect(m.map((e) => e.id).toSet(), hasLength(3));
    expect(dataChanged, 0);
  });
}
