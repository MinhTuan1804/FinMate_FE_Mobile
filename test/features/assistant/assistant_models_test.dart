import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../../fixtures/fixture.dart';

ChatReply _chat(String fixtureName) => ChatReply.fromJson(fixtureData(fixtureName) as Map<String, dynamic>);

void main() {
  group('ChatReply (response chat thật)', () {
    test('saved: có giao dịch đã tạo', () {
      final r = _chat('chat_saved');

      expect(r.action, ChatAction.saved);
      expect(r.transaction!.amountCents, BigInt.from(55000));
      expect(r.transaction!.categoryName, 'Ăn uống');
      expect(r.transaction!.type, TransactionType.expense);
    });

    test('summary: tổng chi và danh sách danh mục', () {
      final r = _chat('chat_summary');
      final json = (fixtureData('chat_summary') as Map)['summary'] as Map;

      expect(r.action, ChatAction.summary);
      expect(r.summary!.metric, 'expense');
      expect(r.summary!.periodLabel, 'tháng này');
      expect(r.summary!.expenseCents, BigInt.from(json['expenseCents'] as int));
      expect(r.summary!.items, isNotEmpty);
      expect(r.summary!.items.first.slug, (json['items'] as List).first['categorySlug']);
      expect(r.summary!.items.first.share, isA<double>());
    });

    test('reply: ngoài phạm vi và thiếu số tiền', () {
      final out = _chat('chat_reply_out_of_scope');
      expect(out.action, ChatAction.reply);
      expect(out.intent, 'out_of_scope');
      expect(out.replyText, isNotEmpty);

      final missing = _chat('chat_reply_needs_amount');
      expect(missing.action, ChatAction.reply);
      expect(missing.intent, 'needs_amount');
      expect(missing.replyText, contains('số tiền'));
    });

    test('confirm: bản nháp chi tiêu thiếu danh mục (transactionType chữ thường)', () {
      final r = _chat('chat_confirm_expense');

      expect(r.action, ChatAction.confirm);
      expect(r.draft!.kind, DraftKind.expense);
      expect(r.draft!.type, TransactionType.expense);
      expect(r.draft!.amountCents, BigInt.from(20000000));
      expect(r.draft!.missingFields, ['category']);
      expect(r.draft!.suggestedAccountId, isNotNull);
      expect(r.draft!.source, DraftSource.chat);
    });

    test('confirm: bản nháp chuyển tiền thiếu tài khoản', () {
      final r = _chat('chat_confirm_transfer');

      expect(r.draft!.kind, DraftKind.transfer);
      expect(r.draft!.type, TransactionType.transfer);
      expect(r.draft!.amountCents, BigInt.from(500000));
      expect(r.draft!.missingFields, ['accounts']);
    });

    test('action lạ hoặc thiếu dữ liệu tương ứng → reply với thông điệp chung, không ném', () {
      final unknown = ChatReply.fromJson({'action': 'dance'});
      expect(unknown.action, ChatAction.reply);
      expect(unknown.replyText, isNotEmpty);

      expect(ChatReply.fromJson({'action': 'saved', 'transaction': null}).action, ChatAction.reply);
      expect(ChatReply.fromJson({'action': 'confirm', 'draft': null}).action, ChatAction.reply);
      expect(ChatReply.fromJson({'action': 'summary', 'summary': null}).action, ChatAction.reply);
      expect(ChatReply.fromJson({}).action, ChatAction.reply);
    });
  });

  group('DraftTransaction từ parse và scan-receipt', () {
    test('parse_ok: chi tiêu Ăn uống 45.000 ₫', () {
      final d = DraftTransaction.fromParseJson(fixtureData('parse_ok') as Map<String, dynamic>, source: DraftSource.voice);

      expect(d.amountCents, BigInt.from(45000));
      expect(d.type, TransactionType.expense);
      expect(d.categorySlug, 'food');
      expect(d.source, DraftSource.voice);
      expect(d.transactedAt, isNotNull);
      expect(d.missingFields, isEmpty);
    });

    test('parse_empty: mọi trường null và liệt kê trường thiếu', () {
      final d = DraftTransaction.fromParseJson(fixtureData('parse_empty') as Map<String, dynamic>);

      expect(d.amountCents, isNull);
      expect(d.type, isNull);
      expect(d.categorySlug, isNull);
      expect(d.missingFields, containsAll(['amount', 'category']));
    });

    test('scan_receipt_success: số tiền, cửa hàng, độ tin cậy, nguồn Receipt, không có ngày', () {
      final scan = ReceiptScan.fromJson(fixtureData('scan_receipt_success') as Map<String, dynamic>);

      expect(scan.success, isTrue);
      expect(scan.scanId, isNotEmpty);
      expect(scan.draft.amountCents, BigInt.from(55000));
      expect(scan.draft.merchantName, 'WinMart');
      expect(scan.draft.categorySlug, 'food');
      expect(scan.draft.confidence, 0.7);
      expect(scan.draft.source, DraftSource.receipt);
      expect(scan.draft.scanId, scan.scanId); // bản nháp mang mã lần quét tới lúc Lưu
      expect(scan.draft.transactedAt, isNull);
    });

    test('scan thất bại: success == false và không ném khi thiếu trường', () {
      final scan = ReceiptScan.fromJson({'ocrResult': 'failed'});

      expect(scan.success, isFalse);
      expect(scan.draft.amountCents, isNull);
      expect(scan.draft.missingFields, contains('amount'));
    });

    test('ReceiptScan.fromJson parses groups', () {
      final scan = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>);

      expect(scan.groups, hasLength(2));
      expect(scan.groups.first.categorySlug, 'food');
      expect(scan.groups.first.amountCents, BigInt.from(100000));
      expect(scan.groups.first.items.map((i) => i.name), ['Cà phê sữa', 'Bánh mì']);
      expect(scan.groups.first.items.first.amountCents, BigInt.from(55000));
      expect(scan.groups.last.categorySlug, isNull); // nhóm chưa phân loại
      expect(scan.groups.fold<BigInt>(BigInt.zero, (s, g) => s + g.amountCents), scan.draft.amountCents);
      expect(scan.draft.receiptGroups, hasLength(2)); // bản nháp mang các nhóm tới màn rà soát
    });

    test('ReceiptScan.fromJson tolerates missing groups', () {
      final scan = ReceiptScan.fromJson(fixtureData('scan_receipt_success') as Map<String, dynamic>);
      expect(scan.groups, isEmpty);
      expect(scan.draft.receiptGroups, isEmpty);
      expect(ReceiptScan.fromJson({'ocrResult': 'success', 'groups': null}).groups, isEmpty);
    });

    test('ReceiptScan.fromJson tolerates null/odd group fields', () {
      final scan = ReceiptScan.fromJson({
        'ocrResult': 'success',
        'groups': [
          {'categorySlug': 5, 'amountCents': 'x', 'items': 'nope'},
          {'categorySlug': null, 'amountCents': null, 'items': [{'name': null, 'amountCents': null}, 'lạ', 3]},
          'không phải object',
          null,
        ],
      });

      expect(scan.groups, hasLength(2));
      expect(scan.groups.first.categorySlug, isNull);
      expect(scan.groups.first.amountCents, BigInt.zero);
      expect(scan.groups.first.items, isEmpty);
      expect(scan.groups.last.items.single.name, '');
      expect(scan.groups.last.items.single.amountCents, BigInt.zero);
      expect(ReceiptScan.fromJson({'groups': 'abc'}).groups, isEmpty);
    });

    test('ReceiptGroup.requestId: cùng lần quét + nhóm cho cùng id; khác nhóm/khác lần quét cho id khác', () {
      final scan = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>);
      final food = scan.groups.first;
      final unknown = scan.groups.last;
      // Hai màn dựng từ cùng bản nháp phải ra cùng id để BE trả lại giao dịch cũ thay vì tạo trùng
      final again = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>).groups.first;

      expect(food.requestId(scan.scanId), again.requestId(scan.scanId));
      expect(food.requestId(scan.scanId), isNot(unknown.requestId(scan.scanId)));
      expect(food.requestId(scan.scanId), isNot(food.requestId('another-scan')));
      // Không có scanId: không có gì để cố định, mỗi lần một id mới
      expect(food.requestId(null), isNot(food.requestId(null)));
    });

    test('DraftSource ánh xạ giá trị source của backend', () {
      expect(DraftSource.chat.apiValue, 'Manual');
      expect(DraftSource.voice.apiValue, 'Voice');
      expect(DraftSource.receipt.apiValue, 'Receipt');
    });
  });

  test('TransactionEntity.toRequestJson dùng source của entity (Receipt) thay vì hằng Manual', () {
    final tx = TransactionEntity(
      id: 'x',
      amountCents: BigInt.from(55000),
      type: TransactionType.expense,
      date: DateTime.utc(2026, 10, 9),
      accountId: 'acc',
      clientRequestId: 'req',
      source: 'Receipt',
    );

    expect(tx.toRequestJson()['source'], 'Receipt');
    expect(tx.copyWith(source: 'Voice').toRequestJson()['source'], 'Voice');
    expect(tx.toRequestJson().containsKey('receiptScanId'), isFalse);
    expect(tx.copyWith(receiptScanId: 'scan-1').toRequestJson()['receiptScanId'], 'scan-1');
    expect(TransactionEntity.fromJson(fixtureData('chat_saved')['transaction'] as Map<String, dynamic>).source, 'Manual');
  });

  test('toRequestJson omits receiptGroup when null and includes it when set', () {
    final tx = TransactionEntity(id: 'x', amountCents: BigInt.from(1), type: TransactionType.expense, date: DateTime.utc(2026), accountId: 'acc', source: 'Receipt');

    expect(tx.toRequestJson().containsKey('receiptGroup'), isFalse);
    expect(tx.copyWith(receiptGroup: 'unknown').toRequestJson()['receiptGroup'], 'unknown');
  });

  group('nhiều khoản, ngày và cảnh báo trùng (response thật của BE 2026-10-12)', () {
    test('confirm nhiều khoản: drafts đủ, draft là phần tử đầu, replyText nói rõ số khoản', () {
      final r = _chat('chat_confirm_multi');

      expect(r.action, ChatAction.confirm);
      expect(r.drafts.map((d) => d.amountCents), [BigInt.from(20000), BigInt.from(10000), BigInt.from(50000)]);
      expect(identical(r.draft, r.drafts.first), isTrue);
      expect(r.replyText, contains('3 khoản'));
    });

    test('confirm một khoản (BE cũ không có drafts): drafts chỉ có một phần tử', () {
      final r = _chat('chat_confirm_expense');

      expect(r.drafts, hasLength(1));
      expect(identical(r.draft, r.drafts.single), isTrue);
    });

    test('có thể trùng: mã giao dịch đi theo bản nháp', () {
      final r = _chat('chat_confirm_duplicate');

      expect(r.draft!.possibleDuplicateId, '6234ef1d-5564-4f01-b6d2-808f0fcb0b00');
      expect(_chat('chat_confirm_expense').draft!.possibleDuplicateId, isNull);
    });

    test('ngày trong câu: occurredAt trở thành transactedAt', () {
      final r = _chat('chat_confirm_dated');

      expect(r.draft!.transactedAt, DateTime.parse('2026-10-11T12:00:00+07:00').toLocal());
    });

    test('quét hóa đơn: needsReview đi theo bản nháp', () {
      final scan = ReceiptScan.fromJson(fixtureData('scan_receipt_needs_review') as Map<String, dynamic>);

      expect(scan.draft.needsReview, isTrue);
      expect(scan.draft.possibleDuplicateId, isNull);
      expect(scan.groups, hasLength(2));
      expect(scan.groups.every((g) => g.possibleDuplicateId == null), isTrue);
    });

    test('quét tách nhóm: mã trùng của từng nhóm và của cả bill', () {
      final scan = ReceiptScan.fromJson({
        'ocrResult': 'success',
        'amountCents': 10000,
        'possibleDuplicateTransactionId': 'whole',
        'groups': [
          {'categorySlug': 'food', 'amountCents': 6000, 'items': [], 'possibleDuplicateTransactionId': 'g1'},
          {'categorySlug': 'shopping', 'amountCents': 4000, 'items': []},
        ],
      });

      expect(scan.groups.map((g) => g.possibleDuplicateId), ['g1', null]);
      expect(scan.draft.possibleDuplicateId, 'whole');
      expect(scan.draft.needsReview, isFalse);
    });
  });

  group('ảnh chụp màn hình danh sách đơn (BE 2026-10-12)', () {
    final scan = ReceiptScan.fromJson(fixtureData('scan_receipt_order_list') as Map<String, dynamic>);

    test('mỗi đơn là một bản nháp riêng, không còn chỉ đơn đầu', () {
      expect(scan.orders.map((d) => d.amountCents), [BigInt.from(78742), BigInt.from(224400), BigInt.from(247253)]);
      expect(scan.orders.map((d) => d.merchantName), ['nlp shop LIv B', 'Cow&Kitty', "Mommy's Joy"]);
      expect(scan.orders.every((d) => d.categorySlug == 'shopping'), isTrue);
      expect(scan.orders[1].description, contains('Cow'));
      expect(scan.orders.every((d) => d.source == DraftSource.receipt), isTrue);
    });

    test('đơn không nối với bản ghi quét (mỗi đơn lưu độc lập)', () {
      expect(scan.orders.every((d) => d.scanId == null), isTrue);
    });

    test('bản nháp cấp trên vẫn là đơn đầu (tương thích)', () {
      expect(scan.draft.amountCents, BigInt.from(78742));
      expect(scan.incompleteOrders, 0);
    });

    test('hóa đơn thường không có đơn nào', () {
      final plain = ReceiptScan.fromJson(fixtureData('scan_receipt_success') as Map<String, dynamic>);
      expect(plain.orders, isEmpty);
      expect(plain.incompleteOrders, 0);
    });

    test('số đơn bị cắt dở được giữ lại', () {
      final cut = ReceiptScan.fromJson({
        'ocrResult': 'success',
        'amountCents': 1000,
        'incompleteOrders': 2,
        'orders': [
          {'merchantName': 'A', 'amountCents': 1000, 'description': 'x', 'categorySlug': 'shopping'},
          {'merchantName': 'B', 'amountCents': 2000, 'description': 'y', 'categorySlug': null},
        ],
      });
      expect(cut.incompleteOrders, 2);
      expect(cut.orders.last.categorySlug, isNull);
    });
  });
}
