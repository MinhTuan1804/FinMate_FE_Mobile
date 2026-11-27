import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import '../../fixtures/fixture.dart';

/// Khoản chi lớn chưa rõ đã mua hay định mua ("mua xe 600 triệu"): chat hỏi lại bằng hai nút, chưa ghi gì cho tới khi người dùng chọn.
/// Hình dạng JSON theo `POST /transactions/chat` với intent ambiguous_purchase (confirm kèm khoản nháp và câu hỏi của server).
const _chatJson = {
  'action': 'confirm',
  'intent': 'ambiguous_purchase',
  'replyText': 'Khoản này khá lớn. Bạn muốn ghi lại khoản đã chi, hay hỏi xem có nên mua không?',
  'draft': {
    'kind': 'expense',
    'amountCents': 600000000,
    'transactionType': 'debit',
    'description': 'mua xe',
    'categorySlug': null,
    'missingFields': ['category'],
  },
};

class _Repo extends AssistantRepository {
  PurchaseDraft? checked;
  _Repo() : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId, Map<String, dynamic>? itemContext}) async => ChatReply.fromJson(_chatJson);

  @override
  Future<PurchaseAssessment> purchaseCheck(PurchaseDraft draft) async {
    checked = draft;
    return PurchaseAssessment.fromJson({'status': 'assessable', 'verdict': 'shortfall_risk', 'summary': 'x', 'warnings': []});
  }
}

void main() {
  Future<(AssistantController, _Repo)> asked() async {
    final repo = _Repo();
    final c = AssistantController(repository: repo, retryEvery: null);
    await c.send('mua xe 600 triệu');
    return (c, repo);
  }

  test('hỏi lại: lời của server + một thẻ hai nút, chưa có thẻ ghi chi và chưa đánh giá gì', () async {
    final (c, repo) = await asked();
    final messages = c.state.messages;
    expect(messages.whereType<AssistantText>().map((m) => m.text), contains(_chatJson['replyText']));
    expect(messages.whereType<ClarifyPurchaseCard>(), hasLength(1));
    expect(messages.whereType<DraftCard>(), isEmpty);
    expect(messages.whereType<PurchaseCard>(), isEmpty);
    expect(repo.checked, isNull);
  });

  test('"Hỏi có nên mua": đánh giá khoản này (chỉ đọc), không có thẻ ghi chi', () async {
    final (c, repo) = await asked();
    c.askClarifiedPurchase(c.state.messages.whereType<ClarifyPurchaseCard>().single.id);
    await Future<void>.delayed(Duration.zero);
    expect(repo.checked!.amountCents, BigInt.from(600000000));
    expect(repo.checked!.item, 'mua xe');
    expect(c.state.messages.whereType<PurchaseCard>(), hasLength(1));
    expect(c.state.messages.whereType<DraftCard>(), isEmpty);
    expect(c.state.messages.whereType<ClarifyPurchaseCard>().single.resolved, isTrue);
  });

  test('"Ghi khoản chi": hiện thẻ ghi chi như mọi khoản khác, không đánh giá; bấm lần hai không làm gì thêm', () async {
    final (c, repo) = await asked();
    final id = c.state.messages.whereType<ClarifyPurchaseCard>().single.id;
    c.logClarifiedPurchase(id);
    c.logClarifiedPurchase(id);
    c.askClarifiedPurchase(id);
    expect(c.state.messages.whereType<DraftCard>(), hasLength(1)); // một khoản: thẻ nháp như thường
    expect(c.state.messages.whereType<PurchaseCard>(), isEmpty);
    expect(repo.checked, isNull);
  });
}
