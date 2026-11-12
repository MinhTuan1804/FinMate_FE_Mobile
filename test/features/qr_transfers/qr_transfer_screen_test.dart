import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/qr_transfer_screen.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: GET banks -> qr_banks.json, GET transfers -> [transfersFixture],
/// GET counterparties -> [overridesFixture], POST tạo -> [createFixture], POST cancel -> [cancelFixture],
/// POST lookup -> [lookupFixture], PATCH counterparty -> [updateOverrideFixture], DELETE -> rỗng.
RouteAdapter _adapter({
  String transfersFixture = 'qr_transfers_list',
  String overridesFixture = 'counterparty_overrides_list',
  String createFixture = 'qr_transfer_created',
  String cancelFixture = 'qr_transfer_cancelled',
  String lookupFixture = 'counterparty_override_null',
  String updateOverrideFixture = 'counterparty_override_updated',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/qr/banks')) return respondFixture('qr_banks');
    if (o.path.contains('/cancel')) return respondFixture(cancelFixture);
    if (o.path.contains('/counterparties/lookup')) return respondFixture(lookupFixture);
    if (o.path.contains('/counterparties') && o.method == 'PATCH') return respondFixture(updateOverrideFixture);
    if (o.path.contains('/counterparties') && o.method == 'DELETE') return respondJson({'success': true, 'data': null});
    if (o.path.contains('/counterparties')) return respondFixture(overridesFixture);
    if (o.path.contains('/qr/transfers') && o.method == 'POST') return respondFixture(createFixture);
    if (o.path.contains('/qr/transfers')) return respondFixture(transfersFixture);
    return respondFixture('qr_banks');
  });
}

final _realCategories = (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

Future<void> _pump(WidgetTester tester, RouteAdapter adapter, {List<Category>? categories}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
      categoriesProvider.overrideWith((ref) async => categories ?? _realCategories),
    ],
    child: const MaterialApp(home: QrTransferScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('QrTransferScreen', () {
    testWidgets('hiện danh sách lần quét và danh mục đã nhớ', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('QR chuyển khoản'), findsOneWidget);
      expect(find.text('Đang chờ'), findsWidgets);
      expect(find.text('Đã khớp'), findsWidgets);
      expect(find.textContaining('Đã quá hạn'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-override-ov-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-override-ov-2')), findsOneWidget);
      // Giao dịch đã khớp (qr-2) không có nút Hủy
      expect(find.byKey(const ValueKey('qr-cancel-qr-2')), findsNothing);
      // Giao dịch đang chờ (qr-1, qr-3) có nút Hủy
      expect(find.byKey(const ValueKey('qr-cancel-qr-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-cancel-qr-3')), findsOneWidget);
    });

    testWidgets('lọc theo trạng thái gửi đúng query status', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('qr-status-filter-Pending')));
      await tester.pumpAndSettle();

      final filtered = adapter.requests.where(
        (r) => r.path.contains('/qr/transfers') && r.method == 'GET' && r.queryParameters['status'] == 'Pending',
      );
      expect(filtered, isNotEmpty);
    });

    testWidgets('hủy một lần quét đang chờ thì chuyển trạng thái sang Đã hủy', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('qr-cancel-qr-1')));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('qr-transfer-qr-1'));
      expect(find.descendant(of: row, matching: find.text('Đã hủy')), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-cancel-qr-1')), findsNothing);
    });

    testWidgets('tạo ý định chuyển tiền gửi đúng body và hiện thông báo thành công', (tester) async {
      final adapter = _adapter(transfersFixture: 'qr_transfers_list', overridesFixture: 'counterparty_overrides_list');
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('qr-receiver-bank')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VietinBank (tự khớp)').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('qr-receiver-account')), '1030123456');

      await tester.tap(find.byKey(const ValueKey('qr-sender-bank')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MB Bank (tự khớp)').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('qr-amount')), '500000');

      await tester.tap(find.byKey(const ValueKey('qr-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qr-create-transfer')));
      await tester.pumpAndSettle();

      final createReq = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/qr/transfers'));
      expect(createReq.data, {
        'receiverBankBin': '970415',
        'receiverAccountNumber': '1030123456',
        'receiverName': null,
        'senderBankBin': '970422',
        'amountCents': 500000,
        'message': null,
        'categoryId': '412878cb-aced-4b3f-a2c9-637838245e6f',
      });
      expect(find.text('Đã tạo ý định chuyển tiền. Mở app ngân hàng để hoàn tất.'), findsOneWidget);

      final accountField = tester.widget<TextField>(find.byKey(const ValueKey('qr-receiver-account')));
      expect(accountField.controller!.text, isEmpty);
    });

    testWidgets('tra cứu danh mục đã nhớ: có mapping thì hiện tên danh mục', (tester) async {
      await _pump(tester, _adapter(lookupFixture: 'counterparty_override'));

      await tester.tap(find.byKey(const ValueKey('qr-receiver-bank')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VietinBank (tự khớp)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('qr-receiver-account')), '1030123456');

      await tester.tap(find.byKey(const ValueKey('qr-lookup-counterparty')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã nhớ: Ăn uống'), findsOneWidget);
    });

    testWidgets('đổi danh mục đã nhớ cho một người nhận', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('qr-edit-override-ov-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();

      final patchReq = adapter.requests.firstWhere((r) => r.method == 'PATCH');
      expect(patchReq.path, contains('/counterparties/ov-2'));
      expect(patchReq.data, {'categoryId': '412878cb-aced-4b3f-a2c9-637838245e6f'});
    });

    testWidgets('xóa danh mục đã nhớ thì mục biến mất khỏi danh sách', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('qr-delete-override-ov-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('qr-override-ov-1')), findsNothing);
      expect(find.byKey(const ValueKey('qr-override-ov-2')), findsOneWidget);
    });

    testWidgets('lỗi khi tải danh sách ngân hàng hiện nút Thử lại', (tester) async {
      await _pump(tester, RouteAdapter((o) => throwNetworkDown(o)));

      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
