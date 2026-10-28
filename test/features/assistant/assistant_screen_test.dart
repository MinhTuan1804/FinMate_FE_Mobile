import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_prompt_bar.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import '../../fixtures/fixture.dart';
import '../auth/consent_fakes.dart';

class _MockAccounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _MockAccounts(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// AssistantController có thể đặt sẵn danh sách tin nhắn và ghi lại các lệnh gửi
class _TestAssistant extends AssistantController {
  final List<String> sent = [];
  final List<int> retried = [];

  _TestAssistant() : super(repository: AssistantRepository(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true})))));

  void put(List<ChatMessage> messages, {bool sending = false}) =>
      state = AssistantState(messages: messages, isSending: sending, selectedAccountId: state.selectedAccountId);

  @override
  Future<void> send(String text, {DraftSource source = DraftSource.chat}) async => sent.add(text);

  @override
  Future<void> retry(int errorMessageId) async => retried.add(errorMessageId);
}

final _accounts = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();
final _categories = (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

ChatReply _reply(String name) => ChatReply.fromJson(fixtureData(name) as Map<String, dynamic>);

void main() {
  late _TestAssistant assistant;

  setUp(() => assistant = _TestAssistant());

  Future<void> pumpChat(WidgetTester tester, {Widget? home, GoRouter? router}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthController(repository: ConsentRepo(consentTestUser(terms: true, ai: true))); // đã đồng ý AI: gửi tin nhắn không bị màn đồng ý chen vào
    await auth.checkAuthStatus();
    final overrides = [
      authControllerProvider.overrideWith((ref) => auth),
      assistantControllerProvider.overrideWith((ref) => assistant),
      accountsControllerProvider.overrideWith((ref) => _MockAccounts(AsyncValue.data(_accounts))),
      categoriesProvider.overrideWith((ref) async => _categories),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: router != null ? MaterialApp.router(routerConfig: router) : MaterialApp(home: home ?? const AssistantScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có tin nhắn: hiện gợi ý nhanh; chạm gợi ý gửi đúng nội dung', (tester) async {
    await pumpChat(tester);

    expect(find.text('ăn phở 45k'), findsOneWidget);
    expect(find.text('tháng này tôi tiêu bao nhiêu?'), findsOneWidget);

    await tester.tap(find.text('ăn phở 45k'));
    await tester.pump();

    expect(assistant.sent, ['ăn phở 45k']);
  });

  testWidgets('nhập rồi gửi gọi send và xóa ô nhập; nút gửi khóa khi ô trống', (tester) async {
    await pumpChat(tester);
    IconButton sendButton() => tester.widget<IconButton>(find.byKey(const ValueKey('send-button')));
    expect(sendButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'cafe 55k');
    await tester.pump();
    expect(sendButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pump();

    expect(assistant.sent, ['cafe 55k']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('đang gửi: nút gửi bị khóa và hiện chỉ báo đang trả lời', (tester) async {
    await pumpChat(tester);
    assistant.put([const UserText(0, 'cafe 55k')], sending: true);
    await tester.enterText(find.byType(TextField), 'tin tiếp theo');
    await tester.pump();

    expect(tester.widget<IconButton>(find.byKey(const ValueKey('send-button'))).onPressed, isNull);
    expect(find.text('Đang trả lời...'), findsOneWidget);
  });

  testWidgets('thẻ đã ghi: số tiền, danh mục và số dư sau giao dịch', (tester) async {
    await pumpChat(tester);
    assistant.put([const UserText(0, 'cafe highlands 55k'), SavedCard(1, _reply('chat_saved').transaction!)]);
    await tester.pump();

    expect(find.text('cafe highlands 55k'), findsOneWidget);
    expect(find.text('Đã ghi giao dịch'), findsOneWidget);
    expect(find.text('-55.000 ₫'), findsOneWidget);
    expect(find.textContaining('Ăn uống'), findsWidgets);
  });

  testWidgets('thẻ tóm tắt: kỳ, tổng chi và các danh mục kèm tỷ lệ', (tester) async {
    await pumpChat(tester);
    final summary = _reply('chat_summary').summary!;
    assistant.put([SummaryCard(0, summary)]);
    await tester.pump();

    expect(find.textContaining('tháng này'), findsOneWidget);
    expect(find.text('Tổng chi'), findsOneWidget);
    expect(find.textContaining('${(summary.items.first.share * 100).round()}%'), findsOneWidget);
    expect(find.text(summary.items.first.name), findsOneWidget);
  });

  testWidgets('thẻ nháp thiếu danh mục: nhắc "Cần bổ sung" và nút Xem và lưu mở màn rà soát với đúng tham số', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AssistantScreen()),
      GoRoute(path: '/assistant/review', builder: (_, state) => Text('REVIEW ${(state.extra as ReviewArgs).messageId}')),
    ]);
    await pumpChat(tester, router: router);
    assistant.put([DraftCard(7, _reply('chat_confirm_expense').draft!)]);
    await tester.pump();

    expect(find.textContaining('Cần bổ sung'), findsOneWidget);
    await tester.tap(find.text('Xem và lưu'));
    await tester.pumpAndSettle();

    expect(find.text('REVIEW 7'), findsOneWidget);
  });

  testWidgets('thẻ nháp đã lưu hiện tóm tắt và không còn nút lưu', (tester) async {
    await pumpChat(tester);
    assistant.put([DraftCard(1, _reply('chat_confirm_expense').draft!, resolved: true, resolvedSummary: 'Đã ghi: 20.000.000 ₫ · Thu nhập')]);
    await tester.pump();

    expect(find.text('Đã ghi: 20.000.000 ₫ · Thu nhập'), findsOneWidget);
    expect(find.text('Xem và lưu'), findsNothing);
  });

  testWidgets('lỗi: hiện thông điệp và "Gửi lại" gọi retry đúng id', (tester) async {
    await pumpChat(tester);
    assistant.put([const UserText(0, 'cafe 55k'), const ErrorNote(1, 'Không có kết nối mạng.', retryText: 'cafe 55k')]);
    await tester.pump();

    expect(find.text('Không có kết nối mạng.'), findsOneWidget);
    await tester.tap(find.text('Gửi lại'));
    await tester.pump();

    expect(assistant.retried, [1]);
  });

  testWidgets('tài khoản mặc định là ví tiền mặt; đổi tài khoản được lưu vào controller', (tester) async {
    await pumpChat(tester);

    final cash = _accounts.firstWhere((a) => a.type == AccountType.cash);
    final bank = _accounts.firstWhere((a) => a.type == AccountType.bank);
    expect(assistant.state.selectedAccountId, cash.id);

    await tester.tap(find.byKey(const ValueKey('account-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(bank.name).last);
    await tester.pumpAndSettle();

    expect(assistant.state.selectedAccountId, bank.id);
  });

  testWidgets('thanh "Hỏi FinMate" ở Trang chủ mở màn trợ lý', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: AssistantPromptBar())),
      GoRoute(path: '/assistant', builder: (_, __) => const Text('CHAT PAGE')),
    ]);
    await pumpChat(tester, router: router);

    expect(find.textContaining('Hỏi FinMate'), findsOneWidget);
    await tester.tap(find.textContaining('Hỏi FinMate'));
    await tester.pumpAndSettle();

    expect(find.text('CHAT PAGE'), findsOneWidget);
  });

  testWidgets('thẻ nháp có thể trùng: cảnh báo, vẫn có nút Xem và lưu', (tester) async {
    await pumpChat(tester);
    assistant.put([DraftCard(3, _reply('chat_confirm_duplicate').draft!)]);
    await tester.pump();

    expect(find.textContaining('Có thể trùng'), findsOneWidget);
    expect(find.text('Xem và lưu'), findsOneWidget);
  });

  testWidgets('thẻ nháp không trùng thì không có cảnh báo trùng', (tester) async {
    await pumpChat(tester);
    assistant.put([DraftCard(3, _reply('chat_confirm_expense').draft!)]);
    await tester.pump();

    expect(find.textContaining('Có thể trùng'), findsNothing);
  });

  testWidgets('thẻ nháp có ngày khác hôm nay: hiện ngày; không có ngày thì không hiện', (tester) async {
    await pumpChat(tester);
    assistant.put([DraftCard(1, DraftTransaction(amountCents: BigInt.from(2000000), transactedAt: DateTime(2020, 1, 5, 12)))]);
    await tester.pump();
    expect(find.text('Ngày 05/01/2020'), findsOneWidget);

    assistant.put([DraftCard(2, DraftTransaction(amountCents: BigInt.from(2000000)))]);
    await tester.pump();
    expect(find.textContaining('Ngày '), findsNothing);
  });

  testWidgets('thẻ nháp từ hóa đơn AI chưa chắc: nhắc kiểm tra lại', (tester) async {
    await pumpChat(tester);
    assistant.put([DraftCard(4, DraftTransaction(amountCents: BigInt.from(5000), categorySlug: 'food', needsReview: true))]);
    await tester.pump();

    expect(find.textContaining('nên kiểm tra lại'), findsOneWidget);
  });

  testWidgets('thẻ đã ghi: giao dịch ghi cho ngày khác hôm nay thì hiện ngày', (tester) async {
    await pumpChat(tester);
    final tx = _reply('chat_saved').transaction!;
    assistant.put([SavedCard(1, tx.copyWith(date: DateTime(2020, 1, 5, 12)))]);
    await tester.pump();
    expect(find.text('Ngày 05/01/2020'), findsOneWidget);

    assistant.put([SavedCard(2, tx.copyWith(date: DateTime.now()))]);
    await tester.pump();
    expect(find.textContaining('Ngày '), findsNothing);
  });

  testWidgets('thẻ nháp của hóa đơn đã tách: hiện từng nhóm và số tiền, không chỉ một danh mục cho cả bill', (tester) async {
    await pumpChat(tester);
    final split = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>).draft;
    assistant.put([DraftCard(5, split)]);
    await tester.pumpAndSettle(); // danh mục tải bất đồng bộ

    expect(find.text('Hóa đơn tách thành 2 nhóm'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Chưa phân loại'), findsOneWidget);
    expect(find.text(formatVnd(BigInt.from(100000))), findsOneWidget);
    expect(find.text(formatVnd(BigInt.from(55000))), findsOneWidget);
    expect(find.text('Xem và lưu'), findsOneWidget);
  });

  testWidgets('thẻ nháp của hóa đơn một nhóm vẫn hiện như cũ', (tester) async {
    await pumpChat(tester);
    final split = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>).draft;
    assistant.put([DraftCard(5, split.copyWith(receiptGroups: [split.receiptGroups.first]))]);
    await tester.pump();

    expect(find.textContaining('Hóa đơn tách thành'), findsNothing);
    expect(find.text('Giao dịch cần xác nhận'), findsOneWidget);
  });
}
