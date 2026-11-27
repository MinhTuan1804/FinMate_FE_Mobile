import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/data/data_coverage_repository.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';
import 'package:finmate/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

const _vcb = '78b154c6-c8d8-4b6d-9367-981772ce5382';
const _cash = 'ca6ba2c5-38ea-4af3-a664-a79a191a3ca7';

DataCoverage _coverage({
  int? percent = 50,
  String level = 'poor',
  List<Map<String, dynamic>> accounts = const [],
  List<Map<String, dynamic>> devices = const [],
}) =>
    DataCoverage.fromJson({'windowDays': 30, 'coveragePercent': percent, 'level': level, 'accounts': accounts, 'devices': devices});

void main() {
  /// [coverage] null = BE không trả độ phủ (chưa tải/lỗi): màn hình vẫn dùng bình thường, không có thẻ.
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {DataCoverage? coverage}) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(adapter))),
      dataCoverageProvider.overrideWith((ref) async => coverage),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  group('độ phủ dữ liệu (data-coverage)', () {
    testWidgets('BE không có độ phủ: không có thẻ, danh sách vẫn hiện', (tester) async {
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')));

      expect(find.byKey(const ValueKey('coverage-banner')), findsNothing);
      expect(find.text('Vietcombank'), findsOneWidget);
    });

    testWidgets('poor: thẻ nói đúng số % và số ngày; ví im lặng có ghi chú số ngày', (tester) async {
      final coverage = _coverage(accounts: [
        {'accountId': _vcb, 'accountName': 'Vietcombank', 'status': 'silent', 'silentDays': 3, 'notificationsOff': false},
        {'accountId': _cash, 'accountName': 'Ví tiền mặt', 'status': 'ok', 'silentDays': 0},
      ]);
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')), coverage: coverage);

      expect(find.textContaining('Chỉ 50% số ngày trong 30 ngày gần đây'), findsOneWidget);
      expect(find.byKey(const ValueKey('coverage-open-settings')), findsNothing);
      expect(find.byKey(const ValueKey('coverage-note-$_vcb')), findsOneWidget);
      expect(find.textContaining('Không thấy thông báo từ 3 ngày'), findsOneWidget);
      expect(find.byKey(const ValueKey('coverage-note-$_cash')), findsNothing, reason: 'ví ok không báo động');
    });

    testWidgets('thông báo của app ngân hàng đang tắt: ghi chú nói rõ để người dùng bật lại', (tester) async {
      final coverage = _coverage(accounts: [
        {'accountId': _vcb, 'accountName': 'Vietcombank', 'status': 'silent', 'silentDays': 4, 'notificationsOff': true},
      ]);
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')), coverage: coverage);

      expect(find.textContaining('đang tắt trên máy'), findsOneWidget);
    });

    testWidgets('upload_gap: nhắc mở app để đồng bộ', (tester) async {
      final coverage = _coverage(level: 'good', percent: 95, accounts: [
        {'accountId': _vcb, 'accountName': 'Vietcombank', 'status': 'upload_gap', 'silentDays': 0},
      ]);
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')), coverage: coverage);

      expect(find.textContaining('Mở app để đồng bộ'), findsOneWidget);
    });

    testWidgets('mất quyền đọc thông báo: thẻ cảnh báo kèm nút mở Cài đặt', (tester) async {
      final coverage = _coverage(devices: [
        {'installationId': 'dev-1', 'status': 'permission_lost', 'permissionGranted': false, 'listenerConnected': false},
      ]);
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')), coverage: coverage);

      expect(find.textContaining('Quyền đọc thông báo đang tắt'), findsOneWidget);
      expect(find.byKey(const ValueKey('coverage-open-settings')), findsOneWidget);
    });

    testWidgets('good: thẻ báo tốt; ví ít dữ liệu và trạng thái chưa rõ không báo động', (tester) async {
      final coverage = _coverage(level: 'good', percent: 92, accounts: [
        {'accountId': _vcb, 'accountName': 'Vietcombank', 'status': 'not_enough_data', 'silentDays': 10},
        {'accountId': _cash, 'accountName': 'Ví tiền mặt', 'status': 'unknown'},
      ]);
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')), coverage: coverage);

      expect(find.textContaining('92% số ngày'), findsOneWidget);
      expect(find.byKey(const ValueKey('coverage-note-$_vcb')), findsNothing);
      expect(find.byKey(const ValueKey('coverage-note-$_cash')), findsNothing);
    });

    testWidgets('chưa có thiết bị nào báo (coveragePercent null): không bịa số, không có thẻ', (tester) async {
      await pumpScreen(tester, RouteAdapter((o) => respondFixture('accounts')), coverage: _coverage(percent: null, level: 'unknown'));

      expect(find.byKey(const ValueKey('coverage-banner')), findsNothing);
    });
  });

  testWidgets('hiện danh sách tài khoản với số dư', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('accounts'));
    await pumpScreen(tester, adapter);

    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.textContaining('30.955.000'), findsOneWidget);
  });

  testWidgets('bấm "Xem số dư mới nhất" gọi API balance rồi tải lại danh sách', (tester) async {
    var listCalls = 0;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/balance')) return respondFixture('account_balance');
      listCalls++;
      return respondFixture('accounts');
    });
    await pumpScreen(tester, adapter);
    expect(listCalls, 1);

    await tester.tap(find.text('Xem số dư mới nhất').first);
    await tester.pumpAndSettle();

    expect(listCalls, 2, reason: 'phải tải lại danh sách để số trên thẻ cũng cập nhật, không chỉ snackbar');
    expect(find.textContaining('31.055.000'), findsOneWidget);
  });

  testWidgets('bật/tắt công tắc theo dõi gọi PATCH monitoring', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'PATCH') {
        final updated = {...(fixtureData('accounts') as List)[1] as Map<String, dynamic>, 'isMonitored': false};
        return respondJson({'success': true, 'data': updated});
      }
      return respondFixture('accounts');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('monitoring-ca6ba2c5-38ea-4af3-a664-a79a191a3ca7')));
    await tester.pumpAndSettle();

    expect(adapter.to('/monitoring'), hasLength(1));
  });

  testWidgets('xóa tài khoản: xác nhận rồi gọi DELETE', (tester) async {
    var deletes = 0;
    final adapter = RouteAdapter((o) {
      if (o.method == 'DELETE') {
        deletes++;
        return respondJson({'success': true, 'data': null});
      }
      return respondFixture('accounts');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('delete-78b154c6-c8d8-4b6d-9367-981772ce5382')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    expect(deletes, 1);
  });
}
