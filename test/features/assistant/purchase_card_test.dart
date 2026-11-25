import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/chat_cards.dart';
import '../../fixtures/fixture.dart';

/// Hỏi trước khi mua ("mua iphone 15tr được không?"): thẻ khoản định mua, KHÔNG ghi gì; thẻ tự hỏi backend và hiện kết luận.
/// Hình dạng JSON lấy từ phản hồi thật của `POST /transactions/chat` và `POST /forecast/purchase-check` (2026-11-13).
const _chatJson = {
  'action': 'purchase',
  'intent': 'evaluate_purchase',
  'replyText': 'Mình hiểu khoản định mua của bạn như thế này. Bạn kiểm tra rồi bấm Đánh giá nhé, mình không ghi khoản này vào chi tiêu.',
  'purchase': {'item': 'điện thoại iphone', 'amountCents': 15000000, 'purchaseDate': null, 'categorySlug': null},
};

const _checkJson = {
  'status': 'assessable',
  'verdict': 'off_plan',
  'summary': 'Vẫn đủ tiền nhưng lệch kế hoạch ngân sách hoặc kế hoạch tháng.',
  'maxAffordableCents': 34200000,
  'earliestSafeDate': null,
  'warnings': [
    {'code': 'plan_over', 'message': 'Khoản này làm số còn lại trong kế hoạch tháng xuống -4.800.000đ.'},
  ],
};

class _Repo extends AssistantRepository {
  int checks = 0;
  bool failFirst;
  _Repo({this.failFirst = false}) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId, Map<String, dynamic>? itemContext}) async => ChatReply.fromJson(_chatJson);

  @override
  Future<PurchaseAssessment> purchaseCheck(PurchaseDraft draft) async {
    checks++;
    if (failFirst) {
      failFirst = false;
      throw Exception('Máy chủ đang bận');
    }
    return PurchaseAssessment.fromJson(_checkJson);
  }
}

void main() {
  test('phản hồi purchase của backend thành khoản định mua; thiếu giá hoặc giá 0 thì chỉ là câu trả lời chung', () {
    final reply = ChatReply.fromJson(_chatJson);
    expect(reply.action, ChatAction.purchase);
    expect(reply.purchase!.item, 'điện thoại iphone');
    expect(reply.purchase!.amountCents, BigInt.from(15000000));

    expect(ChatReply.fromJson({..._chatJson, 'purchase': null}).action, ChatAction.reply);
    expect(ChatReply.fromJson({..._chatJson, 'purchase': {'item': 'x', 'amountCents': 0}}).action, ChatAction.reply);
  });

  Future<(AssistantController, _Repo)> pump(WidgetTester tester, {bool failFirst = false}) async {
    final repo = _Repo(failFirst: failFirst);
    final c = AssistantController(repository: repo, retryEvery: null);
    await c.send('mua iphone 15tr được không');
    await tester.pumpWidget(ProviderScope(
      overrides: [assistantControllerProvider.overrideWith((ref) => c)],
      child: Consumer(builder: (context, ref, _) {
        final card = ref.watch(assistantControllerProvider).messages.whereType<PurchaseCard>().single;
        return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PurchaseCardView(card: card))));
      }),
    ));
    await tester.pumpAndSettle();
    return (c, repo);
  }

  testWidgets('tự đánh giá, không cần bấm: hỏi backend một lần rồi hiện món, giá, kết luận, câu của backend, cảnh báo và mức mua tối đa', (tester) async {
    final (_, repo) = await pump(tester);

    expect(repo.checks, 1);
    expect(find.text('điện thoại iphone'), findsOneWidget);
    expect(find.text('15.000.000 ₫'), findsOneWidget);
    expect(find.text('Đủ tiền nhưng lệch kế hoạch'), findsOneWidget);
    expect(find.textContaining('lệch kế hoạch ngân sách'), findsOneWidget);
    expect(find.textContaining('xuống -4.800.000đ'), findsOneWidget);
    expect(find.text('Mức mua tối đa lúc này: 34.200.000 ₫'), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-assess')), findsNothing, reason: 'không bắt người dùng bấm Đánh giá');
    expect(find.textContaining('không ghi khoản này vào chi tiêu'), findsOneWidget);
  });

  testWidgets('lần tự đánh giá lỗi: hiện lý do và nút Thử lại; bấm thì hiện kết luận', (tester) async {
    final (_, repo) = await pump(tester, failFirst: true);

    expect(find.textContaining('Máy chủ đang bận'), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-verdict')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('purchase-assess')));
    await tester.pumpAndSettle();

    expect(repo.checks, 2);
    expect(find.text('Đủ tiền nhưng lệch kế hoạch'), findsOneWidget);
  });

  testWidgets('sau lỗi bấm Bỏ qua: thẻ thành một dòng, không hỏi backend thêm', (tester) async {
    final (_, repo) = await pump(tester, failFirst: true);

    await tester.tap(find.byKey(const ValueKey('purchase-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Đã bỏ qua, mình không ghi gì.'), findsOneWidget);
    expect(repo.checks, 1);
  });
}
