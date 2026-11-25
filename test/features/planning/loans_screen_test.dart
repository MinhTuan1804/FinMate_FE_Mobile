import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/presentation/screens/loans_screen.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _loan({String id = 'l1', String direction = 'borrow', int principal = 30000000, int paid = 18000000, String title = 'Vay mua xe'}) => {
      'id': id,
      'direction': direction,
      'title': title,
      'counterparty': 'FE Credit',
      'principalCents': principal,
      'interestRatePercentYear': 9.5,
      'dueDate': '2027-04-15',
      'paidCents': paid,
      'remainingCents': principal - paid,
      'startDate': '2026-01-01',
      'accruedInterestCents': 500000,
      'createdAt': '2026-11-01T00:00:00Z',
    };

RouteAdapter _adapter(List<Map<String, dynamic>> loans, {List<Map<String, dynamic>> accounts = const []}) => RouteAdapter((o) {
      if (o.path.contains('financial-accounts')) return respondJson({'success': true, 'data': accounts});
      if (o.path.endsWith('/repayments')) return respondJson({'success': true, 'data': _loan(paid: 20000000)});
      if (o.method == 'PUT') return respondJson({'success': true, 'data': _loan(title: 'Đã sửa')});
      if (o.path.endsWith('/loans') && o.method == 'POST') return respondJson({'success': true, 'data': _loan()});
      if (o.path.contains('/loans')) return respondJson({'success': true, 'data': loans});
      return respondJson({'success': true, 'data': <dynamic>[]}); // ví
    });

Future<void> _pump(WidgetTester tester, RouteAdapter adapter, {Size size = const Size(800, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
    ],
    child: const MaterialApp(home: LoansScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiện khoản vay từ API (không còn dữ liệu mẫu): tổng dư nợ = tổng còn lại của tab', (tester) async {
    await _pump(tester, _adapter([_loan(), _loan(id: 'l2', direction: 'lend', title: 'Cho bạn mượn', principal: 15000000, paid: 5000000)]));

    expect(find.text('Vay mua xe'), findsOneWidget);
    expect(find.text('Cho bạn mượn'), findsNothing, reason: 'nằm ở tab cho vay');
    expect(find.text('Vay mua xe máy trả góp'), findsNothing);
    expect(find.textContaining('12.000.000'), findsWidgets);

    await tester.tap(find.text('Người khác nợ tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Cho bạn mượn'), findsOneWidget);
    expect(find.textContaining('10.000.000'), findsWidgets);
  });

  testWidgets('chưa có khoản nào: hiện trạng thái trống, không có dữ liệu mẫu', (tester) async {
    await _pump(tester, _adapter([]));
    expect(find.textContaining('không có khoản nợ nào'), findsOneWidget);
  });

  testWidgets('thêm khoản vay: POST /loans đúng direction và số tiền', (tester) async {
    final adapter = _adapter([]);
    await _pump(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-loan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('loan-title')), 'Vay mua xe');
    await tester.enterText(find.byKey(const ValueKey('loan-counterparty')), 'FE Credit');
    await tester.enterText(find.byKey(const ValueKey('loan-amount')), '30000000');
    await tester.tap(find.byKey(const ValueKey('loan-save')));
    await tester.pumpAndSettle();

    final post = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/loans'));
    expect(post.data['direction'], 'borrow');
    expect(post.data['principalCents'], 30000000);
    expect(post.data['title'], 'Vay mua xe');
  });

  testWidgets('ghi nhận trả: gọi /repayments, chặn số tiền vượt phần còn lại', (tester) async {
    final adapter = _adapter([_loan()]);
    await _pump(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('repay-loan-l1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('repay-amount')), '99000000');
    await tester.tap(find.byKey(const ValueKey('repay-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vượt quá số còn lại'), findsOneWidget);
    expect(adapter.requests.any((r) => r.path.endsWith('/repayments')), isFalse);

    await tester.enterText(find.byKey(const ValueKey('repay-amount')), '2000000');
    await tester.tap(find.byKey(const ValueKey('repay-save')));
    await tester.pumpAndSettle();
    final req = adapter.requests.firstWhere((r) => r.path.endsWith('/loans/l1/repayments'));
    expect(req.data['amountCents'], 2000000);
  });

  testWidgets('hiện lãi tạm tính; sửa khoản vay gọi PUT /loans/{id} với dữ liệu điền sẵn', (tester) async {
    final adapter = _adapter([_loan()]);
    await _pump(tester, adapter);

    expect(find.textContaining('Lãi tạm tính'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-loan-l1')));
    await tester.pumpAndSettle();
    expect(find.text('Vay mua xe'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('loan-counterparty')), 'Ngân hàng B');
    await tester.tap(find.byKey(const ValueKey('loan-save')));
    await tester.pumpAndSettle();

    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.path, endsWith('/loans/l1'));
    expect(put.data['counterparty'], 'Ngân hàng B');
    expect(put.data['principalCents'], 30000000);
  });

  testWidgets('sheet trả nợ: chip gợi ý điền số, chọn ví gửi accountId, chỉ ghi sổ hiện giải thích; không tràn ở 360dp', (tester) async {
    final adapter = _adapter([_loan()], accounts: [
      {'id': 'a1', 'accountType': 'Bank', 'accountName': 'Vietcombank', 'balanceCents': 24500000},
      {'id': 'a2', 'accountType': 'Cash', 'accountName': 'Tiền mặt', 'balanceCents': 1000000},
    ]);
    await _pump(tester, adapter, size: const Size(360, 800));

    await tester.tap(find.byKey(const ValueKey('repay-loan-l1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Số dư 24.500.000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repay-chip-all')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '12.000.000'), findsOneWidget);
    expect(find.textContaining('Xác nhận 12.000.000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repay-chip-half')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '6.000.000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repay-account')));
    await tester.pumpAndSettle();
    expect(find.textContaining('không đổi số dư ví'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repay-account-a2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('không đổi số dư ví'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('repay-save')));
    await tester.pumpAndSettle();
    final req = adapter.requests.firstWhere((r) => r.path.endsWith('/loans/l1/repayments'));
    expect(req.data['amountCents'], 6000000);
    expect(req.data['financialAccountId'], 'a2');
    expect(tester.takeException(), isNull);
  });
}
