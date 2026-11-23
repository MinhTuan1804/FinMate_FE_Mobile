import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/agent_answer.dart';
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
  final List<Map<String, dynamic>?> contexts = [];

  @override
  Future<AgentAnswer> askAgent(String question) async => AgentAnswer.fromJson({
        'status': 'answered',
        'claims': [{'text': 'Số dư mỗi tháng khoảng 14.500.000 đồng.', 'evidenceIds': ['capacity_base']}],
        'evidence': [
          {'id': 'income_declared', 'key': 'income_declared', 'valueVnd': 17000000, 'text': 'Thu nhập hằng tháng bạn đã khai', 'unit': 'VND', 'source': 'user_entered', 'asOf': '2026-11-20T10:00:00+07:00', 'confidence': 1.0},
          {'id': 'spend_declared', 'key': 'spend_declared', 'valueVnd': 2500000, 'text': 'Mức chi chọn trong khảo sát', 'unit': 'VND', 'source': 'estimated', 'asOf': '2026-11-20T10:00:00+07:00', 'confidence': 0.5},
          {'id': 'prelim_note', 'key': 'goal_plan_preliminary', 'text': 'Chỉ để tham khảo: mới dựa trên thu nhập bạn khai.', 'unit': 'label', 'source': 'estimated', 'asOf': '2026-11-20T10:00:00+07:00', 'confidence': 0.3},
        ],
        'suggestedActions': [],
      });

  _Repo(this.replies) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId, Map<String, dynamic>? itemContext}) async {
    sent.add(text);
    contexts.add(itemContext);
    return ChatReply.fromJson(replies[sent.length - 1]);
  }
}

void main() {
  late List<ChatItemDraft> created;
  late List<ChatItemDraft> undone;
  late List<BigInt> updated;
  late List<ChatItemDraft> repaid;
  late List<NamedItem> found;
  late List<String> namedLog;

  AssistantController controller(_Repo repo, {bool withCreate = true, bool fails = false, bool missing = false, bool repayFails = false}) => AssistantController(
        repository: repo,
        retryEvery: null,
        findItems: (op) async => found,
        repayLoan: (item) async {
          if (repayFails) throw StateError('Khoản này đã trả hết');
          repaid.add(item);
          return 'Đã ghi: ${item.counterparty} trả bạn ${item.amountCents}.';
        },
        createItem: withCreate
            ? (item, {createCategory = false}) async {
                if (missing && !createCategory) throw const MissingCategory('Thú cưng');
                if (fails) throw StateError('Bạn chưa có nhóm này');
                created.add(item);
                return ItemOutcome('Đã lưu ${item.kind}.', () async => undone.add(item), update: (cents) async {
                  updated.add(cents);
                  return 'Đã sửa thành $cents.';
                });
              }
            : null,
      );

  setUp(() {
    created = [];
    undone = [];
    updated = [];
    repaid = [];
    found = [];
    namedLog = [];
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

  test('nhóm chưa có trong tài khoản: thẻ hỏi có tạo nhóm không; đồng ý thì tạo rồi đặt ngân sách, không thì không tạo gì', () async {
    final c = controller(_Repo([itemReply(kind: 'budget'), itemReply(kind: 'budget')]), missing: true);

    await c.send('đặt ngân sách thú cưng 1 triệu');
    var card = c.state.messages.whereType<ItemCard>().single;
    expect((card.status, card.missingCategory), (ItemCardStatus.needsCategory, 'Thú cưng'));
    expect(created, isEmpty);

    await c.confirmNewCategory(card.id);
    expect(created, hasLength(1));
    expect(c.state.messages.whereType<ItemCard>().single.status, ItemCardStatus.created);

    await c.send('đặt ngân sách thú cưng 1 triệu');
    card = c.state.messages.whereType<ItemCard>().last;
    c.declineNewCategory(card.id);
    expect(c.state.messages.whereType<ItemCard>().last.status, ItemCardStatus.declined);
    expect(created, hasLength(1));
  });

  Map<String, dynamic> opReply(String operation, {int cents = 0, String kind = 'budget'}) => {
        'action': 'item',
        'intent': 'create_item',
        'item': {'kind': kind, 'amountCents': cents, 'categorySlug': 'food', 'operation': operation},
      };

  test('việc vừa tạo được gửi kèm làm ngữ cảnh ở các tin sau; chưa tạo gì thì không gửi', () async {
    final repo = _Repo([itemReply(kind: 'budget'), {'action': 'reply', 'intent': 'greet', 'replyText': 'ok'}]);
    final c = controller(repo);

    await c.send('đặt ngân sách ăn uống 2 triệu');
    await c.send('đổi thành 3 triệu');

    expect(repo.contexts.first, isNull);
    expect(repo.contexts.last, {'kind': 'budget', 'amountCents': 2000000, 'categorySlug': 'food'});
  });

  test('câu nối tiếp: đổi số tiền, cộng thêm, rồi xóa đúng việc vừa tạo; sau khi xóa thì không còn ngữ cảnh', () async {
    final repo = _Repo([itemReply(kind: 'budget'), opReply('update', cents: 3000000), opReply('add', cents: 500000), opReply('delete'), opReply('update', cents: 1000000)]);
    final c = controller(repo);

    await c.send('đặt ngân sách ăn uống 2 triệu');
    await c.send('đổi thành 3 triệu');
    await c.send('thêm 500k nữa');
    expect(updated, [BigInt.from(3000000), BigInt.from(3500000)]); // cộng thêm tính trên số đã sửa

    await c.send('xóa cái đó');
    expect(undone, hasLength(1));
    expect(c.state.messages.whereType<ItemCard>().single.status, ItemCardStatus.undone);

    await c.send('đổi thành 1 triệu');
    expect(updated, hasLength(2)); // không còn gì để sửa
    expect(repo.contexts.last, isNull);
    expect(c.state.messages.whereType<AssistantText>().last.text, contains('chưa rõ'));
  });

  test('thao tác khác loại với việc vừa tạo thì hỏi lại, không đoán', () async {
    final repo = _Repo([itemReply(kind: 'loan'), opReply('update', cents: 3000000)]);
    final c = controller(repo);

    await c.send('bạn An nợ tôi 700k');
    await c.send('đổi thành 3 triệu');

    expect(updated, isEmpty);
    expect(c.state.messages.whereType<AssistantText>().last.text, contains('chưa rõ'));
  });

  Map<String, dynamic> repayReply() => {
        'action': 'item',
        'intent': 'add_income',
        'item': {
          'kind': 'loan',
          'amountCents': 500000,
          'name': 'Cho Bạn An vay',
          'direction': 'lend',
          'counterparty': 'Bạn An',
          'operation': 'repay',
          'loanId': 'loan-1',
          'remainingCents': 700000,
          'financialAccountId': 'wallet-1',
        },
      };

  test('trả nợ khớp một khoản vay: hỏi xác nhận (còn lại bao nhiêu), đồng ý mới ghi, không có Hoàn tác', () async {
    final c = controller(_Repo([repayReply()]));

    await c.send('bạn An đã trả cho tôi 500k');

    var card = c.state.messages.whereType<ItemCard>().single;
    expect(card.status, ItemCardStatus.needsConfirm);
    expect(card.question, allOf(contains('500.000'), contains('200.000'), contains('ví')));
    expect(repaid, isEmpty);

    await c.confirmRepayment(card.id);
    expect(repaid.single.loanId, 'loan-1');
    card = c.state.messages.whereType<ItemCard>().single;
    expect(card.summary, contains('Bạn An trả bạn'));
    await c.confirmRepayment(card.id); // bấm lại không ghi lần hai
    expect(repaid, hasLength(1));
  });

  test('không đồng ý ghi lần trả, hoặc ghi lỗi: không ghi gì, lỗi thì bấm lại được', () async {
    final c = controller(_Repo([repayReply(), repayReply()]), repayFails: true);

    await c.send('bạn An đã trả cho tôi 500k');
    final failing = c.state.messages.whereType<ItemCard>().single;
    await c.confirmRepayment(failing.id);
    expect(c.state.messages.whereType<ItemCard>().single.status, ItemCardStatus.needsConfirm);
    expect(c.state.messages.whereType<ItemCard>().single.error, contains('trả hết'));

    await c.send('bạn An đã trả cho tôi 500k');
    final second = c.state.messages.whereType<ItemCard>().last;
    c.declineRepayment(second.id);
    expect(c.state.messages.whereType<ItemCard>().last.status, ItemCardStatus.declined);
    expect(repaid, isEmpty);
  });

  NamedItem named(String label, {int cents = 2000000}) => NamedItem(
        kind: 'budget',
        label: label,
        amountCents: BigInt.from(cents),
        update: (c) async {
          namedLog.add('update:$c');
          return 'Đã đổi $label thành $c.';
        },
        delete: () async => namedLog.add('delete:$label'),
      );

  Map<String, dynamic> namedReply(String operation, {int cents = 0}) => {
        'action': 'item',
        'intent': 'create_item',
        'item': {'kind': 'any', 'amountCents': cents, 'name': 'Netflix', 'operation': operation},
      };

  test('sửa theo tên: tìm thấy đúng một mục thì đổi ngay, Hoàn tác trả về số cũ', () async {
    found = [named('ngân sách Ăn uống')];
    final c = controller(_Repo([namedReply('update_named', cents: 3000000)]));

    await c.send('tăng ngân sách ăn uống lên 3 triệu');

    expect(namedLog, ['update:3000000']);
    final card = c.state.messages.whereType<ItemCard>().single;
    expect(card.status, ItemCardStatus.created);
    await c.undoItem(card.id);
    expect(namedLog, ['update:3000000', 'update:2000000']);
  });

  test('xóa theo tên: luôn hỏi xác nhận; đồng ý mới xóa, không thì không xóa gì', () async {
    found = [named('khoản định kỳ "Netflix"')];
    final c = controller(_Repo([namedReply('delete_named'), namedReply('delete_named')]));

    await c.send('xóa gói Netflix');
    var card = c.state.messages.whereType<ItemCard>().single;
    expect(card.status, ItemCardStatus.needsConfirm);
    expect(card.question, contains('Netflix'));
    expect(namedLog, isEmpty);
    await c.confirmRepayment(card.id);
    expect(namedLog, ['delete:khoản định kỳ "Netflix"']);
    expect(c.state.messages.whereType<ItemCard>().single.summary, contains('Đã xóa'));

    await c.send('xóa gói Netflix');
    card = c.state.messages.whereType<ItemCard>().last;
    c.declineRepayment(card.id);
    expect(c.state.messages.whereType<ItemCard>().last.status, ItemCardStatus.declined);
    expect(namedLog, hasLength(1));
  });

  test('không thấy hoặc nhiều mục khớp: nói rõ, không sửa gì', () async {
    final c = controller(_Repo([namedReply('update_named', cents: 300000), namedReply('update_named', cents: 300000)]));

    await c.send('đổi khoản Netflix thành 300k');
    expect(c.state.messages.whereType<AssistantText>().last.text, contains('không thấy mục nào tên "Netflix"'));

    found = [named('ngân sách A'), named('khoản B')];
    await c.send('đổi khoản Netflix thành 300k');
    expect(c.state.messages.whereType<AssistantText>().last.text, allOf(contains('2 mục'), contains('ngân sách A')));
    expect(namedLog, isEmpty);
  });

  test('ngân sách tổng và thu nhập định kỳ là việc tạo thường: tạo ngay, nhớ làm ngữ cảnh', () async {
    final repo = _Repo([
      {'action': 'item', 'intent': 'create_item', 'item': {'kind': 'budget_total', 'amountCents': 15000000}},
      {'action': 'item', 'intent': 'create_item', 'item': {'kind': 'recurring', 'amountCents': 15000000, 'name': 'Lương', 'cadence': 'monthly', 'nextDue': '2026-12-05', 'direction': 'inflow'}},
    ]);
    final c = controller(repo);

    await c.send('đặt ngân sách tổng 15 triệu');
    await c.send('lương 15 triệu hằng tháng ngày 5');

    expect(created.map((i) => (i.kind, i.direction)), [('budget_total', null), ('recurring', 'inflow')]);
    expect(repo.contexts.last, containsPair('kind', 'budget_total'));
  });

  test('xin giải thích số: đọc bằng chứng của câu trả lời agent gần nhất, không gọi AI; chưa có câu trả lời thì nói rõ', () async {
    final repo = _Repo([
      {'action': 'reply', 'intent': 'explain_numbers'},
      {'action': 'reply', 'intent': 'ask_agent'},
      {'action': 'reply', 'intent': 'explain_numbers'},
    ]);
    final c = controller(repo);

    await c.send('số này tính thế nào');
    expect(c.state.messages.whereType<AssistantText>().last.text, contains('chưa có con số nào'));

    await c.send('đặt mục tiêu mua nhà');
    await c.send('vì sao ô số dư ra 14,5 triệu?');

    final text = c.state.messages.whereType<AssistantText>().last.text;
    expect(text, allOf(contains('Thu nhập hằng tháng bạn đã khai: 17.000.000'), contains('do bạn nhập hoặc khai'), contains('Mức chi chọn trong khảo sát: 2.500.000'), contains('ước tính'), contains('Chỉ để tham khảo')));
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
