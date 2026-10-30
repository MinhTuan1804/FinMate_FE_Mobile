import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import '../../fixtures/fixture.dart';

class _FakeBridge extends NotificationBridge {
  final List<List<String>> pushed = [];
  int flushes = 0;
  bool sessionExpired = false;
  int clears = 0;
  bool? expiredFlagWhenCleared; // giá trị sessionExpiredProvider tại lúc clearSession được gọi
  bool Function()? readExpiredFlag;

  @override
  Future<void> clearSession() async {
    clears++;
    expiredFlagWhenCleared = readExpiredFlag?.call();
  }

  @override
  Future<void> setMonitoredPackages(List<String> packages) async => pushed.add(packages);

  @override
  Future<void> flushQueue() async => flushes++;

  @override
  Future<bool> consumeSessionExpired() async {
    final v = sessionExpired;
    sessionExpired = false;
    return v;
  }

  @override
  Future<bool> isNotificationAccessEnabled() async => true;
}

// Không đụng mạng: danh sách tài khoản do test đặt trực tiếp.
class _StubAccounts extends AccountsController {
  _StubAccounts() : super(repository: AccountsRepository(apiClient: testApiClient(RouteAdapter((o) => respondFixture('accounts')))), enabled: false);

  void emit(List<FinancialAccount> list) => state = AsyncValue.data(list);
  void emitState(AsyncValue<List<FinancialAccount>> v) => state = v;
}

FinancialAccount _acc(String id, {String? pkg, bool monitored = true}) => FinancialAccount(
      id: id,
      type: AccountType.bank,
      name: id,
      packageName: pkg,
      isMonitored: monitored,
      balanceCents: BigInt.zero,
    );

void main() {
  test('monitoredPackagesOf_filters_unmonitored_blank_and_duplicates', () {
    final result = monitoredPackagesOf([
      _acc('a', pkg: 'com.VCB'),
      _acc('b', pkg: 'com.mbmobile', monitored: false),
      _acc('c', pkg: ''),
      _acc('d', pkg: '  '),
      _acc('e'),
      _acc('f', pkg: 'com.VCB'),
      _acc('g', pkg: 'vn.vnpay.vnpayewallet'),
    ]);

    expect(result, ['com.VCB', 'vn.vnpay.vnpayewallet']);
  });

  group('NotificationCaptureScope', () {
    final loaded = [_acc('a', pkg: 'com.VCB'), _acc('b', pkg: 'com.x', monitored: false), _acc('c')];

    // Mặc định: đã đăng nhập, danh sách đang tải (giống lúc khởi động thật). Controller `enabled: false` mặc định là data([]),
    // đúng cái trạng thái từng bị đẩy nhầm xuống native khi chưa đăng nhập.
    Future<(_FakeBridge, ProviderContainer, _StubAccounts)> mount(
      WidgetTester tester, {
      bool expired = false,
      String? userId = 'u1',
      AsyncValue<List<FinancialAccount>> initial = const AsyncValue.loading(),
    }) async {
      final bridge = _FakeBridge()..sessionExpired = expired;
      final accounts = _StubAccounts()..emitState(initial);
      // Container dựng trước để fake đọc được sessionExpiredProvider ngay khi scope gọi clearSession.
      final container = ProviderContainer(overrides: [
        notificationBridgeProvider.overrideWithValue(bridge),
        currentUserIdProvider.overrideWith((ref) => userId),
        accountsControllerProvider.overrideWith((ref) => accounts),
      ]);
      addTearDown(container.dispose);
      bridge.readExpiredFlag = () => container.read(sessionExpiredProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationCaptureScope(child: SizedBox())),
      ));
      await tester.pump();
      return (bridge, container, accounts);
    }

    testWidgets('pushes_packages_when_accounts_load', (tester) async {
      final (bridge, _, accounts) = await mount(tester);
      expect(bridge.pushed, isEmpty, reason: 'đang tải thì chưa đẩy');

      accounts.emit(loaded);
      await tester.pump();

      expect(bridge.pushed, [
        ['com.VCB', 'com.android.shell'] // test chạy ở chế độ debug nên có thêm gói adb
      ]);
    });

    testWidgets('does_not_push_while_loading_or_on_error', (tester) async {
      final (bridge, _, accounts) = await mount(tester);

      accounts.emitState(AsyncValue.error(Exception('offline'), StackTrace.empty));
      await tester.pump();
      accounts.emitState(const AsyncValue.loading());
      await tester.pump();

      expect(bridge.pushed, isEmpty);
    });

    testWidgets('does_not_push_when_signed_out', (tester) async {
      // Đăng xuất / khởi động khi chưa biết người dùng: controller phát data([]) nhưng đó không phải danh sách thật.
      final (bridge, _, accounts) = await mount(tester, userId: null, initial: const AsyncValue.data([]));

      accounts.emit(loaded);
      await tester.pump();

      expect(bridge.pushed, isEmpty);
    });

    testWidgets('pushes_empty_list_when_signed_in_user_has_loaded_empty_accounts', (tester) async {
      final (bridge, _, accounts) = await mount(tester);

      accounts.emit([_acc('a', pkg: 'com.x', monitored: false)]);
      await tester.pump();

      expect(bridge.pushed, [
        ['com.android.shell']
      ]);
    });

    testWidgets('flushes_queue_on_start_and_on_resume', (tester) async {
      final (bridge, _, _) = await mount(tester);
      expect(bridge.flushes, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(bridge.flushes, 2);
    });

    testWidgets('session_expired_flag_sets_sessionExpiredProvider', (tester) async {
      final (bridge, container, _) = await mount(tester, expired: true);

      expect(container.read(sessionExpiredProvider), isTrue);
      // Xóa phiên native (gói theo dõi, baseUrl cũ) TRƯỚC khi đặt cờ hết phiên.
      expect(bridge.clears, 1);
      expect(bridge.expiredFlagWhenCleared, isFalse);
    });
  });
}
