import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/profile_screen.dart';
import '../auth/consent_fakes.dart';
import '../../fixtures/fixture.dart';

class MockAuthController extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  int logouts = 0;

  MockAuthController(super.state);

  @override
  Future<void> logout() async => logouts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final user = UserProfile(
    id: 'u1',
    email: 'probe@example.com',
    displayName: 'Probe',
    isEmailVerified: true,
    notificationPrefs: NotificationPrefs.defaultPrefs(),
    createdAt: DateTime(2026),
  );

  late AppDatabase db;
  late MockAuthController auth;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = MockAuthController(AsyncValue.data(user));
  });

  tearDown(() => db.close());

  Future<void> pumpProfile(WidgetTester tester, {AuthController? controller, bool subscriptionsEnabled = true}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => controller ?? auth),
        databaseProvider.overrideWithValue(db),
        // Màn đọc thêm danh sách ví, ngưỡng cảnh báo và gói đăng ký: trả fixture thay vì gọi mạng thật.
        apiClientProvider.overrideWithValue(testApiClient(RouteAdapter((o) {
          if (o.path.contains('/financial-accounts')) return respondFixture('accounts');
          if (o.path.contains('/alert-thresholds')) return respondFixture('alert_thresholds');
          if (o.path.contains('/subscriptions/me')) {
            return respondJson({
              'success': true,
              'data': {'enabled': subscriptionsEnabled, 'planCode': 'free', 'planName': 'Miễn phí', 'isFree': true, 'nextPurchaseStartsAt': '2026-11-10T10:00:00Z', 'upcoming': [], 'features': []},
              'error': null,
              'meta': null,
            });
          }
          return respondJson({'success': true, 'data': null});
        }))),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/profile', routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('WELCOME')),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('gói đăng ký tắt (features.subscriptions = false): ẩn mục "Gói đăng ký" dù các mục cùng nhóm vẫn hiện', (tester) async {
    await pumpProfile(tester, subscriptionsEnabled: false);

    await tester.scrollUntilVisible(find.text('Cách quản lý tài chính'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Cách quản lý tài chính'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-subscription')), findsNothing);
    expect(find.text('Gói đăng ký'), findsNothing);
  });

  testWidgets('gói đăng ký bật: mục "Gói đăng ký" hiện lại', (tester) async {
    await pumpProfile(tester, subscriptionsEnabled: true);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('open-subscription')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Gói đăng ký'), findsOneWidget);
  });

  testWidgets('hiện tên và email, không còn cấp độ/XP/tủ đồ', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Probe'), findsOneWidget);
    expect(find.text('probe@example.com'), findsOneWidget);
    expect(find.textContaining('Cấp '), findsNothing);
    expect(find.textContaining('XP'), findsNothing);
    expect(find.text('TỦ ĐỒ LINH VẬT FINNY'), findsNothing);
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
  });

  testWidgets('hiện thu nhập dự kiến, ví đã liên kết, ngưỡng cảnh báo và số quyền đồng ý đang bật từ dữ liệu thật', (tester) async {
    final withIncome = UserProfile(
      id: 'u1',
      email: 'probe@example.com',
      displayName: 'Probe',
      monthlyIncomeCents: 35000000,
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime(2026),
      termsAccepted: true,
      aiConsentGranted: true,
    );
    await pumpProfile(tester, controller: MockAuthController(AsyncValue.data(withIncome)));

    expect(find.text('Cài đặt & Tài khoản'), findsOneWidget);
    expect(find.text('35.000.000 ₫/tháng'), findsOneWidget);
    expect(find.text('Nhắc ở 70% và 90%'), findsOneWidget);
    expect(find.textContaining('tài khoản đã liên kết'), findsOneWidget);
    expect(find.text('2/3 đang bật'), findsOneWidget);
    expect(find.text('PRO'), findsNothing, reason: 'gói miễn phí không có huy hiệu');
  });

  testWidgets('ở 360dp với tên và thu nhập dài không tràn bố cục', (tester) async {
    final longName = UserProfile(
      id: 'u1',
      email: 'ten.rat.dai.cua.nguoi.dung@example.com',
      displayName: 'Nguyễn Văn Một Cái Tên Rất Là Dài',
      monthlyIncomeCents: 1234567890,
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime(2026),
    );
    await pumpProfile(tester, controller: MockAuthController(AsyncValue.data(longName)));
    tester.view.physicalSize = const Size(360, 2400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('chưa đặt thu nhập thì ghi "Chưa đặt", không bịa số; chế độ giao diện đổi được', (tester) async {
    await pumpProfile(tester);
    expect(find.text('Chưa đặt'), findsOneWidget);

    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<ThemeMode>>(find.byKey(const ValueKey('theme-mode'))).selected, {ThemeMode.dark});
  });

  testWidgets('đăng xuất khi còn giao dịch chưa gửi: hỏi xác nhận, Hủy thì không đăng xuất', (tester) async {
    await db.enqueueSync(SyncQueueCompanion.insert(clientRequestId: 'x', endpoint: '/e', payload: '{}', createdAt: DateTime.now()));
    await pumpProfile(tester);

    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Còn giao dịch chưa đồng bộ'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(auth.logouts, 0);
  });

  testWidgets('đăng xuất khi không còn gì chờ đồng bộ: gọi logout ngay', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();

    expect(auth.logouts, 1);
    expect(find.text('Còn giao dịch chưa đồng bộ'), findsNothing);
    expect(find.text('WELCOME'), findsOneWidget);
  });

  testWidgets('Hồ sơ không còn công tắc quyền riêng tư; rút lại đồng ý nằm ở "Quyền đồng ý"', (tester) async {
    await pumpProfile(tester, controller: AuthController(repository: ConsentRepo(consentTestUser(terms: true, ai: true, training: true))));
    expect(find.byKey(const ValueKey('ai-consent-switch')), findsNothing);
    expect(find.byKey(const ValueKey('training-consent-switch')), findsNothing);
  });
}
