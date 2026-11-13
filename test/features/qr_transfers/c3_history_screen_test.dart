import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c3_history_screen.dart';
import '../../fixtures/fixture.dart';

RouteAdapter _adapter({required List<Map<String, dynamic>> transfers}) {
  return RouteAdapter((o) => respondJson({'success': true, 'data': transfers}));
}

Map<String, dynamic> _transfer({
  required String id,
  required String status,
  String? categoryName,
  String? matchedTransactionId,
}) => {
      'id': id,
      'receiverBankBin': '970436',
      'receiverBankName': 'Vietcombank',
      'receiverAccountNumber': '0123456789',
      'receiverName': 'NGUYEN VAN A',
      'senderBankBin': '970422',
      'senderBankName': 'MB Bank',
      'amountCents': '50000',
      'message': null,
      'categoryId': categoryName == null ? null : 'cat-1',
      'categoryName': categoryName,
      'status': status,
      'isExpired': false,
      'scannedAt': DateTime.now().toIso8601String(),
      'matchedAt': matchedTransactionId == null ? null : DateTime.now().toIso8601String(),
      'matchedTransactionId': matchedTransactionId,
    };

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const C3HistoryScreen()),
      GoRoute(path: '/transactions', builder: (context, state) => const Scaffold(body: Text('Lịch sử giao dịch'))),
      GoRoute(path: '/home', builder: (context, state) => const Scaffold(body: Text('Trang chủ'))),
      GoRoute(path: '/qr-transfers/scan', builder: (context, state) => const Scaffold(body: Text('Quét QR'))),
      GoRoute(path: '/planning', builder: (context, state) => const Scaffold(body: Text('Kế hoạch'))),
      GoRoute(path: '/analytics', builder: (context, state) => const Scaffold(body: Text('Phân tích'))),
      GoRoute(path: '/qr-transfers/beneficiaries', builder: (context, state) => const Scaffold(body: Text('Người nhận đã lưu'))),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('C3HistoryScreen', () {
    testWidgets('không hiện chip danh mục; đổi đúng nhãn trạng thái', (tester) async {
      final adapter = _adapter(transfers: [
        _transfer(id: 't-1', status: 'Pending', categoryName: 'Cho vay / Mượn'),
        _transfer(id: 't-2', status: 'Cancelled'),
      ]);
      await _pump(tester, adapter);

      expect(find.text('Cho vay / Mượn'), findsNothing);
      expect(find.text('Chờ ngân hàng xác nhận'), findsOneWidget);
      expect(find.text('Đã hủy ý định'), findsOneWidget);
      expect(find.text('Đang chờ'), findsNothing);
      expect(find.text('Đã hủy'), findsNothing);
    });

    testWidgets('dòng đã khớp bấm vào thì sang /transactions', (tester) async {
      final adapter = _adapter(transfers: [
        _transfer(id: 't-3', status: 'Matched', matchedTransactionId: 'tx-99'),
      ]);
      await _pump(tester, adapter);

      expect(find.text('Đã khớp vào sổ giao dịch'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('c3-transfer-t-3')));
      await tester.pumpAndSettle();

      expect(find.text('Lịch sử giao dịch'), findsOneWidget);
    });

    testWidgets('dòng chưa khớp (Pending) không điều hướng khi bấm', (tester) async {
      final adapter = _adapter(transfers: [
        _transfer(id: 't-4', status: 'Pending'),
      ]);
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('c3-transfer-t-4')));
      await tester.pumpAndSettle();

      expect(find.text('Lịch sử quét QR'), findsOneWidget);
    });
  });
}
