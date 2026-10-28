import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import '../../fixtures/fixture.dart';

class _MockAccounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _MockAccounts(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingTx extends StateNotifier<AsyncValue<List<TransactionEntity>>> implements TransactionController {
  final List<Map<String, dynamic>> created = [];
  final List<Map<String, dynamic>> transfers = [];
  Object? error;

  /// Giữ lần lưu "đang chạy" cho tới khi test complete
  Completer<void>? gate;

  /// Nhóm hóa đơn sẽ lỗi ở lần gửi kế tiếp (mỗi nhóm lỗi một lần)
  final Set<String> failGroupsOnce = {};
  final List<Map<String, dynamic>> attempts = [];

  _RecordingTx() : super(const AsyncValue.data([]));

  @override
  Future<void> createTransaction({
    required String accountId,
    String? categoryId,
    required BigInt amountCents,
    required TransactionType type,
    String? merchantName,
    String description = '',
    required DateTime date,
    String source = 'Manual',
    String? receiptScanId,
    String? receiptGroup,
    String? clientRequestId,
  }) async {
    attempts.add({'receiptGroup': receiptGroup, 'clientRequestId': clientRequestId});
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    if (failGroupsOnce.remove(receiptGroup)) throw Exception('Máy chủ đang bận');
    created.add({'accountId': accountId, 'categoryId': categoryId, 'amount': amountCents, 'type': type, 'merchant': merchantName, 'description': description, 'date': date, 'source': source, 'receiptScanId': receiptScanId, 'receiptGroup': receiptGroup});
  }

  @override
  Future<void> transferInternal({
    required BigInt amountCents,
    required String fromAccountId,
    required String toAccountId,
    String description = '',
    required DateTime date,
  }) async {
    transfers.add({'amount': amountCents, 'from': fromAccountId, 'to': toAccountId, 'description': description});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _accounts = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();
final _categories = (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

void main() {
  late _RecordingTx tx;
  late AssistantController assistant;

  setUp(() {
    tx = _RecordingTx();
    assistant = AssistantController(repository: AssistantRepository(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true})))));
  });

  Future<void> openReview(WidgetTester tester, DraftTransaction draft, {List<FinancialAccount>? accounts, int? messageId}) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        transactionControllerProvider.overrideWith((ref) => tx),
        accountsControllerProvider.overrideWith((ref) => _MockAccounts(AsyncValue.data(accounts ?? _accounts))),
        categoriesProvider.overrideWith((ref) async => _categories),
        assistantControllerProvider.overrideWith((ref) => assistant),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionReviewScreen(args: ReviewArgs(draft, messageId: messageId)))),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Xác nhận & Lưu giao dịch'));
    await tester.tap(find.text('Xác nhận & Lưu giao dịch'));
    await tester.pumpAndSettle();
  }

  testWidgets('bản nháp "lương" bị AI coi là chi: đổi sang Thu nhập rồi lưu với source Manual', (tester) async {
    await openReview(
      tester,
      DraftTransaction(amountCents: BigInt.from(20000000), type: TransactionType.expense, description: 'luong', missingFields: const ['category']),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Thu nhập'));
    await tester.pump();
    await tapSave(tester);

    expect(tx.created.single['type'], TransactionType.income);
    expect(tx.created.single['amount'], BigInt.from(20000000));
    expect(tx.created.single['source'], 'Manual');
  });

  testWidgets('nguồn giọng nói và hóa đơn được gửi đúng', (tester) async {
    await openReview(tester, DraftTransaction(amountCents: BigInt.from(1000), type: TransactionType.expense, source: DraftSource.voice));
    await tapSave(tester);
    expect(tx.created.single['source'], 'Voice');
  });

  testWidgets('hóa đơn: source Receipt, ngày null dùng thời điểm hiện tại, cảnh báo độ tin cậy thấp', (tester) async {
    final before = DateTime.now();
    await openReview(
      tester,
      DraftTransaction(amountCents: BigInt.from(55000), type: TransactionType.expense, merchantName: 'WinMart', categorySlug: 'food', source: DraftSource.receipt, confidence: 0.7),
    );

    expect(find.text('AI cần bạn kiểm tra lại một số chi tiết'), findsOneWidget);
    await tapSave(tester);

    final saved = tx.created.single;
    expect(saved['source'], 'Receipt');
    expect(saved['merchant'], 'WinMart');
    expect((saved['date'] as DateTime).isBefore(before), isFalse);
  });

  testWidgets('categorySlug "food" chọn sẵn danh mục Ăn uống và được gửi kèm categoryId', (tester) async {
    await openReview(tester, DraftTransaction(amountCents: BigInt.from(45000), type: TransactionType.expense, categorySlug: 'food'));
    await tapSave(tester);

    expect(tx.created.single['categoryId'], _categories.firstWhere((c) => c.slug == 'food').id);
  });

  testWidgets('tài khoản mặc định theo suggestedAccountId', (tester) async {
    final second = _accounts.last;
    await openReview(tester, DraftTransaction(amountCents: BigInt.from(1000), type: TransactionType.expense, suggestedAccountId: second.id));
    await tapSave(tester);

    expect(tx.created.single['accountId'], second.id);
  });

  for (final amount in <BigInt?>[null, BigInt.zero, BigInt.parse('1000000000000')]) {
    testWidgets('số tiền ${amount ?? 'trống'} bị chặn: báo lỗi và không gọi API', (tester) async {
      await openReview(tester, DraftTransaction(amountCents: amount, type: TransactionType.expense));
      await tapSave(tester);

      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
      expect(tx.created, isEmpty);
    });
  }

  testWidgets('chưa có tài khoản: chặn lưu với thông báo rõ ràng', (tester) async {
    await openReview(tester, DraftTransaction(amountCents: BigInt.from(1000), type: TransactionType.expense), accounts: const []);
    await tapSave(tester);

    expect(find.text('Bạn cần có ít nhất một tài khoản để lưu giao dịch'), findsOneWidget);
    expect(tx.created, isEmpty);
  });

  testWidgets('chuyển tiền: gọi transferInternal với hai tài khoản khác nhau, không có danh mục', (tester) async {
    await openReview(
      tester,
      DraftTransaction(kind: DraftKind.transfer, type: TransactionType.transfer, amountCents: BigInt.from(500000), missingFields: const ['accounts']),
    );
    await tapSave(tester);

    expect(tx.created, isEmpty);
    final t = tx.transfers.single;
    expect(t['amount'], BigInt.from(500000));
    expect(t['from'], isNot(t['to']));
  });

  testWidgets('chuyển tiền khi danh sách tài khoản đang trống (lúc tải lại sau khi lưu): màn vẫn dựng được, hai ô tài khoản không trùng khóa', (tester) async {
    await openReview(
      tester,
      DraftTransaction(kind: DraftKind.transfer, type: TransactionType.transfer, amountCents: BigInt.from(500000)),
      accounts: const [],
    );

    // Lỗi thật trên máy: "Duplicate keys found ... 'acc-null-0'" rồi sinh '_dependents.isEmpty' ở framework.dart
    expect(tester.takeException(), isNull);
    expect(find.text('TỪ TÀI KHOẢN'), findsOneWidget);
    expect(find.text('ĐẾN TÀI KHOẢN'), findsOneWidget);
  });

  group('chiều chuyển tiền theo câu nói', () {
    FinancialAccount acc(String id, String name, [AccountType type = AccountType.cash]) =>
        FinancialAccount(id: id, type: type, name: name, balanceCents: BigInt.from(1000000));
    // Ví tiết kiệm đứng ĐẦU danh sách: trước đây nó luôn thành ví nguồn, tiền chạy ngược chiều so với "chuyển SANG tiết kiệm"
    final savingsFirst = [acc('savings', 'Tiết kiệm', AccountType.bank), acc('wallet', 'Ví'), acc('momo', 'MoMo', AccountType.eWallet)];

    DraftTransaction transfer(String description, {String? suggested}) => DraftTransaction(
          kind: DraftKind.transfer,
          type: TransactionType.transfer,
          amountCents: BigInt.from(2000000),
          description: description,
          suggestedAccountId: suggested,
          missingFields: const ['accounts'],
        );

    testWidgets('"chuyển sang tiết kiệm": đích là Tiết kiệm dù nó đứng đầu danh sách, nguồn là ví khác', (tester) async {
      await openReview(tester, transfer('chuyển sang tiết kiệm'), accounts: savingsFirst);
      await tapSave(tester);

      final t = tx.transfers.single;
      expect(t['to'], 'savings');
      expect(t['from'], isNot('savings'));
    });

    testWidgets('ví đang chọn ở chat trùng với ví đích: nguồn chuyển sang ví khác thay vì chuyển cho chính nó', (tester) async {
      await openReview(tester, transfer('chuyển sang tiết kiệm', suggested: 'savings'), accounts: savingsFirst);
      await tapSave(tester);

      final t = tx.transfers.single;
      expect(t['to'], 'savings');
      expect(t['from'], isNot('savings'));
    });

    testWidgets('ví đang chọn ở chat được giữ làm nguồn khi không trùng ví đích', (tester) async {
      await openReview(tester, transfer('chuyển sang tiết kiệm', suggested: 'momo'), accounts: savingsFirst);
      await tapSave(tester);

      expect(tx.transfers.single, containsPair('from', 'momo'));
      expect(tx.transfers.single, containsPair('to', 'savings'));
    });

    testWidgets('"rút từ tiết kiệm về ví": nguồn là Tiết kiệm, đích là Ví', (tester) async {
      await openReview(tester, transfer('rút từ tiết kiệm về ví'), accounts: [acc('wallet', 'Ví'), acc('savings', 'Tiết kiệm', AccountType.bank)]);
      await tapSave(tester);

      expect(tx.transfers.single, containsPair('from', 'savings'));
      expect(tx.transfers.single, containsPair('to', 'wallet'));
    });

    testWidgets('câu nói không chỉ hướng: giữ cách chọn cũ (ví đầu tiên làm nguồn, ví kế tiếp làm đích)', (tester) async {
      await openReview(tester, transfer('chuyển tiền'), accounts: savingsFirst);
      await tapSave(tester);

      expect(tx.transfers.single, containsPair('from', 'savings'));
      expect(tx.transfers.single, containsPair('to', 'wallet'));
    });

    testWidgets('người dùng tự đổi ví đích thì lựa chọn của họ thắng gợi ý từ câu nói', (tester) async {
      await openReview(tester, transfer('chuyển sang tiết kiệm'), accounts: savingsFirst);
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MoMo').last);
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(tx.transfers.single, containsPair('to', 'momo'));
    });
  });

  testWidgets('chuyển tiền khi chỉ có một tài khoản: chặn lưu', (tester) async {
    await openReview(
      tester,
      DraftTransaction(kind: DraftKind.transfer, type: TransactionType.transfer, amountCents: BigInt.from(500000)),
      accounts: [_accounts.first],
    );
    await tapSave(tester);

    expect(find.text('Cần ít nhất 2 tài khoản để chuyển tiền'), findsOneWidget);
    expect(tx.transfers, isEmpty);
  });

  testWidgets('lỗi khi lưu hiện thông điệp thân thiện và ở lại màn', (tester) async {
    tx.error = Exception('Tài khoản không tồn tại');
    await openReview(tester, DraftTransaction(amountCents: BigInt.from(1000), type: TransactionType.expense));
    await tapSave(tester);

    expect(find.text('Tài khoản không tồn tại'), findsOneWidget);
    expect(find.text('Xác nhận & Lưu giao dịch'), findsOneWidget);
  });

  testWidgets('lưu thành công đóng màn và đánh dấu thẻ nháp trong chat đã xử lý', (tester) async {
    assistant.addDraft(DraftTransaction(amountCents: BigInt.from(45000), type: TransactionType.expense, categorySlug: 'food'));
    final card = assistant.state.messages.whereType<DraftCard>().single;

    await openReview(tester, card.draft, messageId: card.id);
    await tapSave(tester);

    expect(find.text('Xác nhận & Lưu giao dịch'), findsNothing);
    final resolved = assistant.state.messages.whereType<DraftCard>().single;
    expect(resolved.resolved, isTrue);
    expect(resolved.resolvedSummary, contains('45.000 ₫'));
    expect(resolved.resolvedSummary, contains('Ăn uống'));
  });

  group('hóa đơn tách nhóm', () {
    final split = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>).draft;
    String categoryId(String slug) => _categories.firstWhere((c) => c.slug == slug).id;

    Future<void> tapSaveSplit(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('review screen shows one card per group with its total and item names', (tester) async {
      await openReview(tester, split);

      expect(find.byKey(const ValueKey('receipt-group-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('receipt-group-1')), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Chưa phân loại'), findsOneWidget);
      expect(find.text('100.000 ₫'), findsOneWidget);
      expect(find.text('55.000 ₫'), findsOneWidget);
      expect(find.text('Cà phê sữa, Bánh mì'), findsOneWidget);
      expect(find.text('Khăn giấy, Pin AA'), findsOneWidget);
      // Bill tách nhóm không hiện ô số tiền chung và danh mục chung
      expect(find.text('SỐ TIỀN (VNĐ)'), findsNothing);
      expect(find.text('Xác nhận & Lưu giao dịch'), findsNothing);
      expect(find.text('Lưu 2 giao dịch'), findsOneWidget);
    });

    testWidgets('đổi danh mục một nhóm: categoryId theo lựa chọn, receiptGroup vẫn là nhóm gốc', (tester) async {
      await openReview(tester, split);

      await tester.tap(find.text('Đổi danh mục').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mua sắm').last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa phân loại'), findsNothing);
      await tapSaveSplit(tester, 'Lưu 2 giao dịch');

      expect(tx.created, hasLength(2));
      expect(tx.created[0], containsPair('receiptGroup', 'food'));
      expect(tx.created[0], containsPair('categoryId', categoryId('food')));
      expect(tx.created[0]['amount'], BigInt.from(100000));
      expect(tx.created[1], containsPair('receiptGroup', 'unknown'));
      expect(tx.created[1], containsPair('categoryId', categoryId('shopping')));
      expect(tx.created[1]['amount'], BigInt.from(55000));
      for (final c in tx.created) {
        expect(c['receiptScanId'], split.scanId);
        expect(c['source'], 'Receipt');
      }
      expect(tx.attempts.map((a) => a['clientRequestId']).toSet(), hasLength(2)); // mỗi nhóm một clientRequestId
      expect(find.text('Lưu 2 giao dịch'), findsNothing); // đã đóng màn
    });

    testWidgets('skip a group sends only the other; nhóm cuối cùng không bỏ được', (tester) async {
      await openReview(tester, split);

      await tester.tap(find.text('Bỏ nhóm').first);
      await tester.pumpAndSettle();
      expect(find.text('Giữ lại'), findsOneWidget);
      final lastSkip = tester.widget<TextButton>(find.ancestor(of: find.text('Bỏ nhóm'), matching: find.byWidgetPredicate((w) => w is TextButton)));
      expect(lastSkip.onPressed, isNull);

      await tapSaveSplit(tester, 'Lưu 1 giao dịch');

      expect(tx.created.single['receiptGroup'], 'unknown');
      expect(tx.created.single['amount'], BigInt.from(55000));
    });

    testWidgets('nhóm sau lỗi: nhóm đầu giữ đã lưu, thử lại chỉ gửi nhóm lỗi với cùng clientRequestId', (tester) async {
      tx.failGroupsOnce.add('unknown');
      await openReview(tester, split);

      await tapSaveSplit(tester, 'Lưu 2 giao dịch');

      expect(tx.created.single['receiptGroup'], 'food');
      expect(find.text('Máy chủ đang bận'), findsOneWidget);
      expect(find.text('Đã lưu'), findsOneWidget);
      await tapSaveSplit(tester, 'Lưu 1 giao dịch');

      expect(tx.created.map((c) => c['receiptGroup']), ['food', 'unknown']);
      expect(tx.attempts.map((a) => a['receiptGroup']), ['food', 'unknown', 'unknown']);
      expect(tx.attempts[2]['clientRequestId'], tx.attempts[1]['clientRequestId']);
      expect(find.text('Lưu 1 giao dịch'), findsNothing);
    });

    testWidgets('back/X/Hủy are disabled while saving', (tester) async {
      tx.gate = Completer<void>();
      await openReview(tester, split);

      await tester.ensureVisible(find.text('Lưu 2 giao dịch'));
      await tester.tap(find.text('Lưu 2 giao dịch'));
      await tester.pump();

      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, LucideIcons.x)).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Hủy bỏ bản ghi nháp')).onPressed, isNull);
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump();
      expect(find.byKey(const ValueKey('receipt-group-0')), findsOneWidget); // vẫn ở màn rà soát

      tx.gate!.complete();
      await tester.pumpAndSettle();
      expect(tx.created, hasLength(2));
      expect(find.byKey(const ValueKey('receipt-group-0')), findsNothing);
    });

    testWidgets('chat card is not marked done until all kept groups are saved', (tester) async {
      tx.failGroupsOnce.add('unknown');
      assistant.addDraft(split);
      final card = assistant.state.messages.whereType<DraftCard>().single;
      await openReview(tester, card.draft, messageId: card.id);

      await tapSaveSplit(tester, 'Lưu 2 giao dịch');
      expect(assistant.state.messages.whereType<DraftCard>().single.resolved, isFalse); // còn nhóm lỗi: thẻ vẫn mở lại được

      await tapSaveSplit(tester, 'Lưu 1 giao dịch');
      final resolved = assistant.state.messages.whereType<DraftCard>().single;
      expect(resolved.resolved, isTrue);
      expect(resolved.resolvedSummary, contains('155.000 ₫'));
    });

    testWidgets('hóa đơn một nhóm vẫn dùng màn cũ', (tester) async {
      final one = split.copyWith(receiptGroups: [split.receiptGroups.first]);
      await openReview(tester, one);

      expect(find.byKey(const ValueKey('receipt-group-0')), findsNothing);
      await tapSave(tester);
      expect(tx.created.single['receiptGroup'], isNull);
      expect(tx.created.single['amount'], BigInt.from(155000));
    });
  });

  group('cảnh báo trùng và kiểm tra lại (BE 2026-10-12)', () {
    testWidgets('bản nháp có thể trùng: hiện cảnh báo trùng và vẫn lưu được', (tester) async {
      await openReview(tester, DraftTransaction(amountCents: BigInt.from(200000), type: TransactionType.expense, categorySlug: 'food', possibleDuplicateId: 'abc'));

      expect(find.textContaining('có thể trùng'), findsOneWidget);
      await tapSave(tester);
      expect(tx.created, hasLength(1));
    });

    testWidgets('bill tách nhóm: một nhóm có thể trùng thì cảnh báo nói về nhóm', (tester) async {
      final split = ReceiptScan.fromJson(fixtureData('scan_receipt_split') as Map<String, dynamic>).draft;
      final withDup = split.copyWith(receiptGroups: [
        ReceiptGroup(categorySlug: split.receiptGroups.first.categorySlug, amountCents: split.receiptGroups.first.amountCents, items: split.receiptGroups.first.items, possibleDuplicateId: 'g1'),
        ...split.receiptGroups.skip(1),
      ]);
      await openReview(tester, withDup);

      expect(find.textContaining('Có nhóm có thể trùng'), findsOneWidget);
    });

    testWidgets('hóa đơn AI chưa chắc (needsReview): hiện khung kiểm tra lại dù độ tin cậy cao', (tester) async {
      await openReview(tester, DraftTransaction(amountCents: BigInt.from(5000), type: TransactionType.expense, categorySlug: 'food', confidence: 0.95, needsReview: true, source: DraftSource.receipt));

      expect(find.text('AI cần bạn kiểm tra lại một số chi tiết'), findsOneWidget);
    });

    testWidgets('bản nháp sạch: không có khung cảnh báo', (tester) async {
      await openReview(tester, DraftTransaction(amountCents: BigInt.from(5000), type: TransactionType.expense, categorySlug: 'food', confidence: 0.95));

      expect(find.text('AI cần bạn kiểm tra lại một số chi tiết'), findsNothing);
    });

    testWidgets('ngày của bản nháp (hôm qua) được dùng khi lưu', (tester) async {
      final yesterday = DateTime(2020, 1, 5, 12);
      await openReview(tester, DraftTransaction(amountCents: BigInt.from(5000), type: TransactionType.expense, categorySlug: 'food', transactedAt: yesterday));
      await tapSave(tester);

      expect(tx.created.single['date'], yesterday);
    });
  });
}
