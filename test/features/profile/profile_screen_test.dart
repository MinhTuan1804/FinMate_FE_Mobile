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

  Future<void> pumpProfile(WidgetTester tester, {AuthController? controller}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => controller ?? auth),
        databaseProvider.overrideWithValue(db),
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

  testWidgets('hiện tên và email, không còn cấp độ/XP/tủ đồ', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Probe'), findsOneWidget);
    expect(find.text('probe@example.com'), findsOneWidget);
    expect(find.textContaining('Cấp '), findsNothing);
    expect(find.textContaining('XP'), findsNothing);
    expect(find.text('TỦ ĐỒ LINH VẬT FINNY'), findsNothing);
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
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

  bool switchValue(WidgetTester tester, String key) =>
      tester.widget<Switch>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Switch))).value;

  testWidgets('phân loại bằng AI: công tắc riêng, bật sẵn sau khi đồng ý Điều khoản; đóng góp dữ liệu là công tắc khác', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true));
    await pumpProfile(tester, controller: AuthController(repository: repo));

    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(switchValue(tester, 'ai-consent-switch'), isTrue);
    expect(switchValue(tester, 'training-consent-switch'), isFalse);
    expect(find.textContaining('Đang bật'), findsWidgets);
    expect(find.text('Rút lại đồng ý'), findsNothing);
  });

  testWidgets('tắt AI: gọi server ngay (không hỏi lại), công tắc tắt; bật lại thì ghi đồng ý AI, không qua màn nào', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true));
    await pumpProfile(tester, controller: AuthController(repository: repo));

    await tester.tap(find.byKey(const ValueKey('ai-consent-switch')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['withdraw:ai']);
    expect(switchValue(tester, 'ai-consent-switch'), isFalse);
    expect(find.textContaining('Đang tắt'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ai-consent-switch')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['withdraw:ai', 'accept:ai']);
    expect(switchValue(tester, 'ai-consent-switch'), isTrue);
  });

  testWidgets('tắt AI bị lỗi mạng: báo lỗi và công tắc vẫn bật (không giả vờ đã tắt)', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true))..failNext = true;
    await pumpProfile(tester, controller: AuthController(repository: repo));

    await tester.tap(find.byKey(const ValueKey('ai-consent-switch')));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được, thử lại nhé'), findsOneWidget);
    expect(switchValue(tester, 'ai-consent-switch'), isTrue);
  });

  testWidgets('đóng góp dữ liệu: mặc định tắt; bật phải qua màn đồng ý, rồi công tắc bật', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true));
    await pumpProfile(tester, controller: AuthController(repository: repo));
    final toggle = find.byKey(const ValueKey('training-consent-switch'));
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty); // chưa ghi gì: đang ở màn đồng ý
    expect(find.textContaining('Tôi đồng ý đóng góp'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Đồng ý và tiếp tục'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['accept:training']);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isTrue);
  });

  testWidgets('đóng góp dữ liệu: "Để sau" ở màn đồng ý thì công tắc vẫn tắt', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true));
    await pumpProfile(tester, controller: AuthController(repository: repo));
    final toggle = find.byKey(const ValueKey('training-consent-switch'));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isFalse);
  });

  testWidgets('đóng góp dữ liệu đang bật: tắt có hỏi xác nhận (nói rõ dữ liệu bị xóa) rồi gọi server', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, training: true));
    await pumpProfile(tester, controller: AuthController(repository: repo));
    final toggle = find.byKey(const ValueKey('training-consent-switch'));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining('dữ liệu bạn đã đóng góp sẽ bị xóa'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Rút lại và xóa'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['withdraw:training']);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isFalse);
  });

  testWidgets('rút lại đóng góp dữ liệu bị lỗi mạng: báo lỗi và công tắc vẫn bật (không giả vờ đã rút)', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, training: true))..failNext = true;
    await pumpProfile(tester, controller: AuthController(repository: repo));
    final toggle = find.byKey(const ValueKey('training-consent-switch'));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Rút lại và xóa'));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được, thử lại nhé'), findsOneWidget);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isTrue);
  });

  testWidgets('đóng góp dữ liệu độc lập với đồng ý AI: bật AI không bật nó, rút AI không tắt nó', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true, training: true));
    await pumpProfile(tester, controller: AuthController(repository: repo));
    final toggle = find.byKey(const ValueKey('training-consent-switch'));

    await tester.tap(find.byKey(const ValueKey('ai-consent-switch')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['withdraw:ai']);
    expect(tester.widget<Switch>(find.descendant(of: toggle, matching: find.byType(Switch))).value, isTrue);
  });
}
