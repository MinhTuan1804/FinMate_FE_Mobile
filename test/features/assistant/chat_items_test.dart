import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import '../../fixtures/fixture.dart';

/// Tạo ngân sách / khoản định kỳ / khoản vay nợ bằng chat: câu ĐỦ thông tin thì tạo ngay (thẻ "Đã lưu" kèm "Hoàn tác"); thiếu thì bot hỏi lại và ghép câu trả lời ngắn vào câu dở.
/// JSON có hình dạng đúng như `ChatItemDraftDto` của backend (camelCase), ghim bằng test hợp đồng ở backend.
Map<String, dynamic> itemReply({String kind = 'recurring'}) => {
      'action': 'item',
      'intent': 'create_item',
      'item': switch (kind) {
        'budget' => {'kind': 'budget', 'amountCents': 2000000, 'categorySlug': 'food'},
        'loan' => {'kind': 'loan', 'amountCents': 700000, 'name': 'Cho Bạn An vay', 'direction': 'lend', 'counterparty': 'Bạn An'},
        _ => {'kind': 'recurring', 'amountCents': 600000, 'name': 'Claude Pro', 'cadence': 'monthly', 'nextDue': '2026-12-05'},
      },
    };

Map<String, dynamic> askReply(String text) => {'action': 'reply', 'intent': 'create_item', 'replyText': text};

class _Repo extends AssistantRepository {
  final List<Map<String, dynamic>> replies;
  final List<String> sent = [];

  _Repo(this.replies) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async {
    sent.add(text);
    return ChatReply.fromJson(replies[sent.length - 1]);
  }
}

void main() {
  late List<ChatItemDraft> created;
  late List<ChatItemDraft> undone;

  AssistantController controller(_Repo repo, {bool withCreate = true, bool fails = false}) => AssistantController(
        repository: repo,
        retryEvery: null,
        createItem: withCreate
            ? (item) async {
                if (fails) throw StateError('Bạn chưa có nhóm này');
                created.add(item);
                return ItemOutcome('Đã lưu ${item.kind}.', () async => undone.add(item));
              }
            : null,
      );

  setUp(() {
    created = [];
    undone = [];
  });

  test('đọc phản hồi item: đủ trường; thiếu số tiền hoặc thiếu item thì chỉ là câu trả lời văn bản', () {
    final reply = ChatReply.fromJson(itemReply());

    expect(reply.action, ChatAction.item);
    final item = reply.item!;
    expect((item.kind, item.amountCents, item.name, item.cadence), ('recurring', BigInt.from(600000), 'Claude Pro', 'monthly'));
    expect((item.nextDue!.year, item.nextDue!.month, item.nextDue!.day), (2026, 12, 5));
    expect(ChatReply.fromJson({'action': 'item', 'intent': 'create_item', 'replyText': 'Bao nhiêu?'}).action, ChatAction.reply);
    expect(ChatReply.fromJson({'action': 'item', 'intent': 'create_item', 'item': {'kind': 'budget', 'amountCents': 0}}).action, ChatAction.reply);
  });

  test('câu đủ thông tin: tạo ngay đúng một lần, thẻ "Đã lưu"; Hoàn tác gọi đúng thứ vừa tạo, chỉ một lần', () async {
    final c = controller(_Repo([itemReply(kind: 'loan')]));

    await c.send('bạn An nợ tôi 700k');

    expect(created.single.counterparty, 'Bạn An');
    final card = c.state.messages.whereType<ItemCard>().single;
    expect(card.status, ItemCardStatus.created);
    await c.undoItem(card.id);
    await c.undoItem(card.id);
    expect(undone, hasLength(1));
    expect(c.state.messages.whereType<ItemCard>().single.status, ItemCardStatus.undone);
  });

  test('tạo lỗi (vd chưa có nhóm): thẻ báo lý do, không có gì để hoàn tác', () async {
    final c = controller(_Repo([itemReply(kind: 'budget')]), fails: true);

    await c.send('đặt ngân sách ăn uống 2 triệu');

    final card = c.state.messages.whereType<ItemCard>().single;
    expect(card.status, ItemCardStatus.failed);
    expect(card.error, contains('chưa có nhóm'));
    await c.undoItem(card.id);
    expect(undone, isEmpty);
  });

  test('app không tạo được loại này: nói thẳng, không hiện thẻ', () async {
    final c = controller(_Repo([itemReply()]), withCreate: false);

    await c.send('gia hạn gói Claude Pro 600k hằng tháng ngày 5');

    expect(c.state.messages.whereType<ItemCard>(), isEmpty);
    expect(c.state.messages.whereType<AssistantText>().single.text, contains('tab Kế hoạch'));
  });

  test('thiếu thông tin: bot hỏi lại, tin ngắn kế tiếp được ghép vào câu dở rồi gửi lại; có thể hỏi nhiều lần cho đến khi đủ', () async {
    final repo = _Repo([askReply('Khoản này lặp lại bao lâu một lần?'), askReply('Lần thanh toán tiếp theo là ngày nào?'), itemReply()]);
    final c = controller(repo);

    await c.send('gia hạn Claude Pro 600k');
    await c.send('hằng tháng');
    await c.send('ngày 5');

    expect(repo.sent, ['gia hạn Claude Pro 600k', 'gia hạn Claude Pro 600k, hằng tháng', 'gia hạn Claude Pro 600k, hằng tháng, ngày 5']);
    expect(created.single.name, 'Claude Pro');
  });

  test('tin dài hoặc là câu hỏi sau câu hỏi lại thì là câu mới, không ghép vào câu dở', () async {
    final repo = _Repo([askReply('Bao lâu một lần?'), {'action': 'reply', 'intent': 'greet', 'replyText': 'ok'}, {'action': 'reply', 'intent': 'greet', 'replyText': 'ok'}]);
    final c = controller(repo);

    await c.send('gia hạn Claude Pro 600k');
    await c.send('tháng này mình tiêu bao nhiêu?');
    await c.send('hằng tháng'); // câu dở đã bị bỏ nhớ

    expect(repo.sent, ['gia hạn Claude Pro 600k', 'tháng này mình tiêu bao nhiêu?', 'hằng tháng']);
  });
}
