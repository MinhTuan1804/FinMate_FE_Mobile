import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/data/loans_repository.dart';
import 'package:finmate/features/planning/presentation/screens/loan_detail_screen.dart';
import 'package:finmate/features/planning/presentation/screens/loans_screen.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _loan({String status = 'open', String direction = 'borrow', int principal = 30000000, int paid = 18000000}) => {
      'id': 'l1',
      'direction': direction,
      'title': 'Vay mua xe',
      'counterparty': 'FE Credit',
      'principalCents': principal,
      'interestRatePercentYear': 9.5,
      'dueDate': '2027-04-15',
      'paidCents': paid,
      'remainingCents': principal - paid,
      'startDate': '2026-01-01',
      'accruedInterestCents': 500000,
      'status': status,
      'createdAt': '2026-11-01T00:00:00Z',
    };

/// Dạng `{ loan, entries[] }` đúng theo docs/loans-api.md của BE.
Map<String, dynamic> _detail({String status = 'open', String direction = 'borrow'}) => {
      'loan': _loan(status: status, direction: direction),
      'entries': [
        {'id': 'e1', 'kind': 'principal', 'amountCents': 30000000, 'at': '2026-01-01T03:00:00Z', 'transactionId': null, 'interestTransactionId': null},
        {'id': 'e2', 'kind': 'repayment', 'amountCents': 18000000, 'at': '2026-03-05T03:00:00Z', 'transactionId': 'tx-9', 'interestTransactionId': 'tx-10'},
      ],
    };

const _summary = {
  'owedToMeCents': 10000000,
  'iOweCents': 99000000,
  'overdueCount': 1,
  'overdueOwedToMeCents': 0,
  'overdueIOweCents': 3000000,
};

/// [onWrite] trả phản hồi cho các lệnh ghi; mặc định trả khoản vay đã cập nhật.
RouteAdapter _adapter({
  Map<String, dynamic>? detail,
  Object? summary = _summary,
  ResponseBody Function(RequestOptions o)? onWrite,
}) =>
    RouteAdapter((o) {
      final path = o.path;
      if (path.contains('financial-accounts')) return respondFixture('accounts');
      if (path == '/api/v1/loans/summary') {
        return summary == null ? ResponseBody.fromString('', 500) : respondJson({'success': true, 'data': summary});
      }
      if (o.method != 'GET') return onWrite != null ? onWrite(o) : respondJson({'success': true, 'data': _loan()});
      if (path == '/api/v1/loans/l1') return respondJson({'success': true, 'data': detail ?? _detail()});
      return respondJson({'success': true, 'data': [_loan()]});
    });

/// Danh sách ở '/', chi tiết ở '/planning/loans/:id' (đúng như app_router) để kiểm cả việc bấm thẻ mở chi tiết.
Future<GoRouter> _pump(WidgetTester tester, RouteAdapter adapter, {String start = '/'}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoansScreen()),
      GoRoute(path: '/planning/loans/:id', builder: (_, s) => LoanDetailScreen(loanId: s.pathParameters['id']!)),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-loan-l1')));
  await tester.pumpAndSettle();
}

void main() {
  group('thẻ tổng hợp ở danh sách (GET /loans/summary)', () {
    testWidgets('tổng và phần quá hạn lấy từ BE, không cộng lại từ danh sách', (tester) async {
      await _pump(tester, _adapter());

      // Danh sách chỉ có một khoản còn lại 12.000.000; BE nói tổng đang nợ 99.000.000: phải hiện số của BE.
      expect(tester.widget<Text>(find.byKey(const ValueKey('loans-total'))).data, contains('99.000.000'));
      expect(find.byKey(const ValueKey('loans-overdue')), findsOneWidget);
      expect(find.textContaining('Đã quá hạn: '), findsOneWidget);
      expect(find.textContaining('3.000.000'), findsWidgets);
    });

    testWidgets('tab "Người khác nợ tôi" dùng owedToMeCents và không có quá hạn thì không hiện dòng quá hạn', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.text('Người khác nợ tôi'));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const ValueKey('loans-total'))).data, contains('10.000.000'));
      expect(find.byKey(const ValueKey('loans-overdue')), findsNothing);
    });

    testWidgets('BE lỗi ở summary: dùng số cộng từ danh sách, màn hình vẫn dùng được', (tester) async {
      await _pump(tester, _adapter(summary: null));

      expect(tester.widget<Text>(find.byKey(const ValueKey('loans-total'))).data, contains('12.000.000'));
      expect(find.byKey(const ValueKey('loans-overdue')), findsNothing);
    });
  });

  group('màn chi tiết', () {
    testWidgets('bấm thẻ khoản vay mở chi tiết: số liệu và các dòng lấy từ BE, dòng mới nhất ở trên', (tester) async {
      await _pump(tester, _adapter());
      await _openDetail(tester);

      expect(find.text('Chi tiết khoản vay'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('loan-remaining'))).data, contains('12.000.000'));
      expect(find.text('Đang mở'), findsOneWidget);
      expect(find.text('Trả nợ'), findsOneWidget);
      expect(find.text('Vay / giải ngân'), findsOneWidget);
      expect(find.textContaining('Kèm giao dịch lãi'), findsOneWidget);
      expect(find.textContaining('Chỉ ghi sổ'), findsOneWidget, reason: 'dòng giải ngân đầu không gắn giao dịch ví');
      // Trả nợ (tháng 3) nằm trên giải ngân (tháng 1).
      expect(tester.getTopLeft(find.byKey(const ValueKey('entry-e2'))).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('entry-e1'))).dy));
    });

    testWidgets('cho vay: nhãn đổi thành "Thu hồi" và "Cho mượn thêm"', (tester) async {
      final adapter = _adapter(detail: _detail(direction: 'lend'));
      await _pump(tester, adapter, start: '/planning/loans/l1');

      expect(find.text('Thu hồi'), findsOneWidget);
      expect(find.text('Cho mượn thêm'), findsOneWidget);
    });

    testWidgets('lỗi tải chi tiết: hiện thông báo và nút Thử lại', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('financial-accounts')) return respondFixture('accounts');
        return ResponseBody.fromString('', 500);
      });
      await _pump(tester, adapter, start: '/planning/loans/l1');

      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('thêm gốc kèm ví: POST /principal gửi đúng số tiền và financialAccountId', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter, start: '/planning/loans/l1');

      await tester.tap(find.byKey(const ValueKey('add-principal')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('principal-amount')), '2500000');
      await tester.tap(find.byKey(const ValueKey('principal-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vietcombank').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('principal-save')));
      await tester.pumpAndSettle();

      final req = adapter.requests.singleWhere((r) => r.path.endsWith('/principal'));
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/loans/l1/principal');
      expect(req.data, {'amountCents': 2500000, 'financialAccountId': '78b154c6-c8d8-4b6d-9367-981772ce5382'});
      expect(find.text('Đã ghi nhận vay thêm.'), findsOneWidget);
    });

    testWidgets('thêm gốc mặc định chỉ ghi sổ (không gửi financialAccountId); thiếu số tiền thì báo lỗi, không gọi API', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter, start: '/planning/loans/l1');

      await tester.tap(find.byKey(const ValueKey('add-principal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('principal-save')));
      await tester.pumpAndSettle();
      expect(find.text('Nhập số tiền lớn hơn 0.'), findsOneWidget);
      expect(adapter.requests.where((r) => r.path.endsWith('/principal')), isEmpty);

      await tester.enterText(find.byKey(const ValueKey('principal-amount')), '1000000');
      await tester.tap(find.byKey(const ValueKey('principal-save')));
      await tester.pumpAndSettle();

      expect(adapter.requests.singleWhere((r) => r.path.endsWith('/principal')).data, {'amountCents': 1000000});
    });

    testWidgets('xóa một dòng: hỏi xác nhận rồi DELETE; BE trả khoản thì ở lại màn chi tiết', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter, start: '/planning/loans/l1');

      await tester.tap(find.byKey(const ValueKey('delete-entry-e2')));
      await tester.pumpAndSettle();
      expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty, reason: 'chưa xác nhận thì chưa gọi');
      await tester.tap(find.byKey(const ValueKey('confirm-delete-entry')));
      await tester.pumpAndSettle();

      expect(adapter.requests.singleWhere((r) => r.method == 'DELETE').path, '/api/v1/loans/l1/entries/e2');
      expect(find.text('Đã xóa dòng.'), findsOneWidget);
      expect(find.text('Chi tiết khoản vay'), findsOneWidget);
    });

    testWidgets('xóa dòng cuối: BE trả 204 (khoản bị xóa theo) thì báo và quay về danh sách', (tester) async {
      final adapter = _adapter(onWrite: (o) => ResponseBody.fromString('', 204));
      await _pump(tester, adapter);
      await _openDetail(tester);

      await tester.tap(find.byKey(const ValueKey('delete-entry-e1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-entry')));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết khoản vay'), findsNothing, reason: 'khoản đã bị xóa nên màn chi tiết đóng');
      expect(find.text('Khoản vay & Nợ'), findsOneWidget);
    });

    testWidgets('xóa nợ: có hộp xác nhận, POST write-off, không gọi khi hủy', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter, start: '/planning/loans/l1');

      await tester.tap(find.byKey(const ValueKey('write-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(adapter.requests.where((r) => r.path.endsWith('/write-off')), isEmpty);

      await tester.tap(find.byKey(const ValueKey('write-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-write-off')));
      await tester.pumpAndSettle();

      final req = adapter.requests.singleWhere((r) => r.path.endsWith('/write-off'));
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/loans/l1/write-off');
      expect(find.text('Đã xóa nợ.'), findsOneWidget);
    });

    testWidgets('khoản đã tất toán hoặc đã xóa nợ: không có nút Xóa nợ (BE từ chối / không có gì đổi)', (tester) async {
      for (final status in ['settled', 'written_off']) {
        await _pump(tester, _adapter(detail: _detail(status: status)), start: '/planning/loans/l1');
        expect(find.byKey(const ValueKey('write-off')), findsNothing, reason: status);
        expect(find.byKey(const ValueKey('add-principal')), findsOneWidget, reason: 'thêm gốc mở lại khoản');
      }
    });

    testWidgets('BE từ chối (422): hiện thông báo của BE, không đóng màn', (tester) async {
      final adapter = _adapter(
        onWrite: (o) => respondJson({
          'success': false,
          'error': {'code': 'LOAN_PRINCIPAL_BELOW_PAID', 'message': 'Gốc sau khi xóa nhỏ hơn số đã trả.'},
        }, status: 422),
      );
      await _pump(tester, adapter, start: '/planning/loans/l1');

      await tester.tap(find.byKey(const ValueKey('delete-entry-e1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-entry')));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết khoản vay'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('LoansRepository', () {
    LoansRepository repo(RouteAdapter a) => LoansRepository(apiClient: testApiClient(a));

    test('getSummary / getDetail gọi đúng đường dẫn và đọc số liệu', () async {
      final adapter = _adapter();
      final r = repo(adapter);

      final summary = await r.getSummary();
      final detail = await r.getDetail('l1');

      expect(adapter.requests.map((q) => q.path), ['/api/v1/loans/summary', '/api/v1/loans/l1']);
      expect(summary.iOweCents, BigInt.from(99000000));
      expect(summary.overdueIOweCents, BigInt.from(3000000));
      expect(summary.overdueCount, 1);
      expect(detail.loan.id, 'l1');
      expect(detail.entries.map((e) => e.kind), [LoanEntryKind.principal, LoanEntryKind.repayment]);
      expect(detail.entries.last.interestTransactionId, 'tx-10');
      expect(detail.entries.first.transactionId, isNull);
    });

    test('addPrincipal và writeOff dùng POST đúng đường dẫn; deleteEntry trả null khi BE trả 204', () async {
      final adapter = _adapter(onWrite: (o) => o.method == 'DELETE' ? ResponseBody.fromString('', 204) : respondJson({'success': true, 'data': _loan()}));
      final r = repo(adapter);

      await r.addPrincipal(loanId: 'l1', amountCents: BigInt.from(500000));
      await r.writeOff('l1');
      final after = await r.deleteEntry(loanId: 'l1', entryId: 'e9');

      expect(adapter.requests.map((q) => '${q.method} ${q.path}'), [
        'POST /api/v1/loans/l1/principal',
        'POST /api/v1/loans/l1/write-off',
        'DELETE /api/v1/loans/l1/entries/e9',
      ]);
      expect(adapter.requests.first.data, {'amountCents': 500000});
      expect(after, isNull);
    });
  });
}
