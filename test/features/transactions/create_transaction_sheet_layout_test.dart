import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';

class _Accounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _Accounts(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tx extends StateNotifier<AsyncValue<List<TransactionEntity>>> implements TransactionController {
  _Tx() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('360dp: không tràn ngang ở 4 chế độ và 3 loại giao dịch; chip cộng nhanh điền số tiền', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final accounts = [
      FinancialAccount(id: 'a1', type: AccountType.cash, name: 'Ví tiền mặt', balanceCents: BigInt.from(4000000)),
      FinancialAccount(id: 'a2', type: AccountType.cash, name: 'Tài khoản ngân hàng có tên rất dài để thử cắt chữ', balanceCents: BigInt.from(1000)),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        transactionControllerProvider.overrideWith((ref) => _Tx()),
        accountsControllerProvider.overrideWith((ref) => _Accounts(AsyncValue.data(accounts))),
        categoriesProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: Scaffold(body: CreateTransactionBottomSheet())),
    ));
    await tester.pumpAndSettle();

    for (final t in ['Giọng nói', 'Hóa đơn', 'Thủ công']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
    }
    for (final t in ['Thu nhập', 'Chuyển tiền', 'Chi tiêu']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('+50.000 ₫'));
    await tester.pumpAndSettle();
    expect(find.text('50.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
