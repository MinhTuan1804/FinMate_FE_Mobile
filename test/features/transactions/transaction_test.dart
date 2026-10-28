import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';
import '../../fixtures/fixture.dart';

class MockAccountsController extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  int creates = 0;
  MockAccountsController(super.state);

  @override
  Future<FinancialAccount> create({required String name, required AccountType type, String? providerConfigId, BigInt? initialBalanceCents}) async {
    creates++;
    return FinancialAccount(id: 'new', type: type, name: name, balanceCents: initialBalanceCents ?? BigInt.zero);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTxController extends StateNotifier<AsyncValue<List<TransactionEntity>>> implements TransactionController {
  Object? createError;
  int creates = 0;
  int loadMores = 0;
  TransactionType? lastFilter;

  FakeTxController(super.state);

  @override
  bool get hasMore => true;

  @override
  TransactionType? get filter => lastFilter;

  @override
  Future<void> setFilter(TransactionType? type) async => lastFilter = type;

  @override
  bool get draftsOnly => false;

  @override
  Future<void> loadMore() async => loadMores++;

  @override
  Future<void> loadTransactions() async {}

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
    if (createError != null) throw createError!;
    creates++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _accounts = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();
final _categories = (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required FakeTxController tx,
  List<FinancialAccount>? accounts,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      transactionControllerProvider.overrideWith((ref) => tx),
      accountsControllerProvider.overrideWith((ref) => MockAccountsController(AsyncValue.data(accounts ?? _accounts))),
      categoriesProvider.overrideWith((ref) async => _categories),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Transaction Domain & Rule Tests', () {
    test('TransactionEntity chi tiêu thông thường', () {
      final tx = TransactionEntity(
        id: 'tx-1',
        amountCents: BigInt.from(150000),
        type: TransactionType.expense,
        categoryName: 'Ăn uống',
        description: 'Ăn trưa phở bò',
        date: DateTime(2026, 9, 30, 12, 30),
        accountId: 'a1',
      );

      expect(tx.formattedAmount, '150.000 ₫');
      expect(tx.isInternalTransfer, false);
      expect(tx.categoryName, 'Ăn uống');
    });

    test('Chuyển tiền nội bộ không gán category chi tiêu (BR-26, BR-27)', () {
      final transfer = TransactionEntity.internalTransfer(
        id: 't1',
        amountCents: BigInt.from(2000000),
        fromAccountId: 'bank',
        toAccountId: 'cash',
        description: 'Rút tiền ATM',
        date: DateTime(2026, 9, 30, 10),
      );

      expect(transfer.isInternalTransfer, true);
      expect(transfer.type, TransactionType.transfer);
      expect(transfer.categoryId, isNull);
      expect(transfer.formattedAmount, '2.000.000 ₫');
    });

    test('Ngày từ server (UTC) được đổi sang giờ địa phương', () {
      final tx = TransactionEntity.fromJson((fixtureData('transactions') as List).first as Map<String, dynamic>);
      expect(tx.date.isUtc, isFalse);
    });
  });

  group('TransactionsScreen', () {
    testWidgets('nhóm theo ngày địa phương, hiện tên danh mục và biểu tượng chưa đồng bộ', (tester) async {
      final tx = FakeTxController(AsyncValue.data([
        TransactionEntity(id: '1', amountCents: BigInt.from(1000), type: TransactionType.expense, categoryName: 'Ăn uống', description: 'A', date: DateTime(2026, 10, 1, 0, 30), accountId: 'a'),
        TransactionEntity(id: '2', amountCents: BigInt.from(2000), type: TransactionType.income, description: 'B', date: DateTime(2026, 9, 30, 23, 30), accountId: 'a', isSynced: false),
      ]));

      await _pump(tester, const TransactionsScreen(), tx: tx);

      expect(find.text('01/10/2026'), findsOneWidget);
      expect(find.text('30/09/2026'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Không phân loại'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing); // dùng icon Lucide, không phải Material
    });

    testWidgets('bấm bộ lọc gọi setFilter; lỗi tải hiện thông điệp thân thiện và nút Thử lại', (tester) async {
      final tx = FakeTxController(const AsyncValue.data([]));
      await _pump(tester, const TransactionsScreen(), tx: tx);

      await tester.tap(find.text('Chi tiêu'));
      await tester.pump();
      expect(tx.lastFilter, TransactionType.expense);

      tx.state = AsyncValue.error(Exception('Máy chủ lỗi'), StackTrace.empty);
      await tester.pump();
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('CreateTransactionBottomSheet', () {
    testWidgets('chưa có tài khoản: hướng dẫn tạo ví, không hiện form', (tester) async {
      await _pump(tester, const CreateTransactionBottomSheet(), tx: FakeTxController(const AsyncValue.data([])), accounts: const []);
      await tester.tap(find.text('Thủ công'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa có tài khoản nào'), findsOneWidget);
      expect(find.text('Tạo ví tiền mặt'), findsOneWidget);
      expect(find.text('Lưu giao dịch'), findsNothing);
    });

    testWidgets('tạo ví tiền mặt với số dư mặc định 0 vẫn thành công (không bị coi là không hợp lệ)', (tester) async {
      final accountsMock = MockAccountsController(const AsyncValue.data([]));
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          transactionControllerProvider.overrideWith((ref) => FakeTxController(const AsyncValue.data([]))),
          accountsControllerProvider.overrideWith((ref) => accountsMock),
          categoriesProvider.overrideWith((ref) async => _categories),
        ],
        child: const MaterialApp(home: Scaffold(body: CreateTransactionBottomSheet())),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thủ công'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo ví tiền mặt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo ví'));
      await tester.pumpAndSettle();

      expect(accountsMock.creates, 1);
    });

    testWidgets('số tiền 0 hoặc rỗng bị chặn, không gọi createTransaction', (tester) async {
      final tx = FakeTxController(const AsyncValue.data([]));
      await _pump(tester, const CreateTransactionBottomSheet(), tx: tx);
      await tester.tap(find.text('Thủ công'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VNĐ)'), '0');
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
      expect(tx.creates, 0);
    });

    testWidgets('lỗi khi lưu hiện thông điệp thân thiện, không đóng form', (tester) async {
      final tx = FakeTxController(const AsyncValue.data([]))..createError = Exception('Tài khoản không tồn tại');
      await _pump(tester, const CreateTransactionBottomSheet(), tx: tx);
      await tester.tap(find.text('Thủ công'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VNĐ)'), '1.500.000');
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pumpAndSettle();

      expect(find.text('Tài khoản không tồn tại'), findsOneWidget);
      expect(find.text('Lưu giao dịch'), findsOneWidget);
    });

    testWidgets('tab AI Text chỉ còn mô tả và nút mở trợ lý (không còn ô nhập/parse cũ)', (tester) async {
      await _pump(tester, const CreateTransactionBottomSheet(), tx: FakeTxController(const AsyncValue.data([])));

      expect(find.text('Mở trợ lý'), findsOneWidget);
      expect(find.text('Phân tích bằng FinMate AI'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tab Giọng nói và Hóa đơn có nút mở trợ lý, không còn "Sắp ra mắt"', (tester) async {
      await _pump(tester, const CreateTransactionBottomSheet(), tx: FakeTxController(const AsyncValue.data([])));

      await tester.tap(find.text('Giọng nói'));
      await tester.pumpAndSettle();
      expect(find.text('Nói để ghi chép'), findsOneWidget);
      expect(find.text('Sắp ra mắt'), findsNothing);

      await tester.tap(find.text('Hóa đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Quét hóa đơn'), findsOneWidget);
      expect(find.text('Sắp ra mắt'), findsNothing);
      expect(find.textContaining('VinMart'), findsNothing);
      expect(find.textContaining('Highland'), findsNothing);
    });
  });
}
