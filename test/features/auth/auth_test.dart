import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/data/auth_repository.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/login_screen.dart';
import 'package:finmate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:finmate/features/auth/presentation/screens/register_screen.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/routes/app_router.dart';

class FakeAuthRepository implements IAuthRepository {
  bool isAuthed = false;
  UserProfile? mockUser;

  /// Mô phỏng việc server có trả token khi xác thực OTP hay không
  bool verifyIssuesTokens = true;
  int verifyCalls = 0;
  Completer<void>? verifyGate;

  ApiException? loginError;

  @override
  Future<UserProfile> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    if (email == 'error@finmate.com') {
      throw Exception('Email hoặc mật khẩu không chính xác.');
    }
    isAuthed = true;
    mockUser = UserProfile(
      id: 'usr-1',
      email: email,
      displayName: 'Nguyen Van A',
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime.now(),
    );
    return mockUser!;
  }

  @override
  Future<void> register({required String email, required String password, required String displayName}) async {
    if (email == 'dup@finmate.com') {
      throw ApiException(message: 'Email đã được sử dụng.', code: 'EMAIL_EXISTS', statusCode: 400);
    }
    mockUser = UserProfile(
      id: 'usr-2',
      email: email,
      displayName: displayName,
      isEmailVerified: false,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<bool> verifyEmail({required String email, required String code}) async {
    verifyCalls++;
    if (verifyGate != null) await verifyGate!.future;
    if (mockUser != null && code == '123456') {
      mockUser = UserProfile(
        id: mockUser!.id,
        email: mockUser!.email,
        displayName: mockUser!.displayName,
        isEmailVerified: true,
        notificationPrefs: mockUser!.notificationPrefs,
        createdAt: mockUser!.createdAt,
      );
      isAuthed = verifyIssuesTokens;
      return verifyIssuesTokens;
    }
    throw ApiException(message: 'Mã xác thực không hợp lệ.', code: 'INVALID_OTP', statusCode: 400);
  }

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<UserProfile> googleLogin({required String idToken}) async {
    isAuthed = true;
    return UserProfile(
      id: 'usr-google',
      email: 'google@finmate.com',
      displayName: 'Google User',
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile> getMe() async {
    if (mockUser != null) return mockUser!;
    throw Exception('Unauthorized');
  }

  ApiException? consentError;

  @override
  Future<UserProfile> acceptConsent(ConsentKind kind) async {
    if (consentError != null) throw consentError!;
    final u = mockUser!;
    return mockUser = u.copyWith(
      termsAccepted: kind == ConsentKind.terms ? true : null,
      aiConsentGranted: kind == ConsentKind.ai ? true : null,
      trainingConsentGranted: kind == ConsentKind.training ? true : null,
    );
  }

  @override
  Future<UserProfile> withdrawConsent(ConsentKind kind) async => mockUser = mockUser!.copyWith(
        aiConsentGranted: kind == ConsentKind.ai ? false : null,
        trainingConsentGranted: kind == ConsentKind.training ? false : null,
      );

  bool updateProfileFails = false;

  @override
  Future<UserProfile> updateProfile({required String displayName, int? monthlyIncomeCents}) async {
    if (updateProfileFails) throw NetworkException();
    mockUser = mockUser?.copyWith(displayName: displayName, monthlyIncomeCents: monthlyIncomeCents);
    return mockUser!;
  }

  @override
  Future<void> updateNotificationPrefs(NotificationPrefs prefs) async {
    mockUser = mockUser?.copyWith(notificationPrefs: prefs);
  }

  @override
  Future<void> logout() async {
    isAuthed = false;
    mockUser = null;
  }

  @override
  Future<bool> isAuthenticated() async => isAuthed;
}

void main() {
  late FakeAuthRepository fakeRepo;
  late AuthController controller;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    controller = AuthController(repository: fakeRepo);
  });

  group('Auth Feature - AuthController Test', () {
    test('Khởi tạo ban đầu: chưa đăng nhập', () async {
      await controller.checkAuthStatus();
      expect(controller.state.value, isNull);
    });

    test('Đăng nhập thành công cập nhật UserProfile vào state', () async {
      await controller.login('test@finmate.com', 'Password123!');
      expect(controller.state.hasValue, isTrue);
      expect(controller.state.value!.email, 'test@finmate.com');
      expect(controller.state.value!.displayName, 'Nguyen Van A');
    });

    test('Đăng nhập thất bại trả về AsyncError', () async {
      await controller.login('error@finmate.com', 'wrong_pass');
      expect(controller.state is AsyncError, isTrue);
    });

    test('Cập nhật thu nhập dự kiến thành công', () async {
      await controller.login('test@finmate.com', 'Password123!');
      await controller.updateMonthlyIncome(25000000); // 25.000.000 VND
      expect(controller.state.value!.monthlyIncomeCents, 25000000);
    });

    test('Đồng ý điều khoản và đồng ý AI cập nhật hồ sơ trong state, không đẩy router về trạng thái tải', () async {
      await controller.login('test@finmate.com', 'Password123!');
      expect((controller.state.value!.termsAccepted, controller.state.value!.aiConsentGranted), (false, false));

      await controller.acceptConsent(ConsentKind.terms);
      await controller.acceptConsent(ConsentKind.ai);
      expect((controller.state.value!.termsAccepted, controller.state.value!.aiConsentGranted), (true, true));

      await controller.withdrawConsent(ConsentKind.ai);
      expect((controller.state.value!.termsAccepted, controller.state.value!.aiConsentGranted), (true, false));
    });

    test('Đồng ý đóng góp dữ liệu huấn luyện tách biệt với đồng ý AI, rút lại thì chỉ tắt đúng nó', () async {
      await controller.login('test@finmate.com', 'Password123!');
      await controller.acceptConsent(ConsentKind.ai);
      await controller.acceptConsent(ConsentKind.training);
      expect((controller.state.value!.aiConsentGranted, controller.state.value!.trainingConsentGranted), (true, true));

      await controller.withdrawConsent(ConsentKind.training);
      expect((controller.state.value!.aiConsentGranted, controller.state.value!.trainingConsentGranted), (true, false));
    });

    test('Đồng ý lỗi: ném lại cho màn hình, hồ sơ giữ nguyên và vẫn đăng nhập', () async {
      await controller.login('test@finmate.com', 'Password123!');
      fakeRepo.consentError = ApiException(message: 'Mạng lỗi', code: 'X', statusCode: 500);

      await expectLater(controller.acceptConsent(ConsentKind.ai), throwsA(isA<ApiException>()));

      expect(controller.state.value!.aiConsentGranted, isFalse);
      expect(controller.state is AsyncError, isFalse);
    });

    test('Đăng xuất xóa sạch dữ liệu người dùng trong state', () async {
      await controller.login('test@finmate.com', 'Password123!');
      await controller.logout();
      expect(controller.state.value, isNull);
    });

    testWidgets('RegisterScreen renders form fields and zero-credential banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Tạo tài khoản mới'), findsOneWidget);
      expect(find.text('HỌ VÀ TÊN'), findsOneWidget);
      expect(find.text('ĐỊA CHỈ EMAIL'), findsOneWidget);
      expect(find.text('MẬT KHẨU'), findsOneWidget);
      expect(find.text('XÁC NHẬN MẬT KHẨU'), findsOneWidget);
      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);
    });

    test('Đăng ký thất bại: ném lại lỗi và không đổi trạng thái đăng nhập', () async {
      await controller.checkAuthStatus();
      await expectLater(
        controller.register('dup@finmate.com', 'Password123!', 'A'),
        throwsA(isA<ApiException>()),
      );
      expect(controller.state.hasError, isFalse);
      expect(controller.state.value, isNull);
    });

    test('Xác thực OTP khi server cấp token: đăng nhập luôn', () async {
      await controller.register('a@finmate.com', 'Password123!', 'A');
      final loggedIn = await controller.verifyEmail('a@finmate.com', '123456');
      expect(loggedIn, isTrue);
      expect(controller.state.value?.isEmailVerified, isTrue);
    });

    test('Xác thực OTP khi server không cấp token: cần đăng nhập lại', () async {
      fakeRepo.verifyIssuesTokens = false;
      await controller.register('a@finmate.com', 'Password123!', 'A');
      final loggedIn = await controller.verifyEmail('a@finmate.com', '123456');
      expect(loggedIn, isFalse);
      expect(controller.state.value, isNull);
    });

    test('OTP sai: ném ApiException với thông điệp thân thiện', () async {
      await controller.register('a@finmate.com', 'Password123!', 'A');
      await expectLater(
        controller.verifyEmail('a@finmate.com', '000000'),
        throwsA(isA<ApiException>().having((e) => errorMessage(e), 'message', 'Mã xác thực không hợp lệ.')),
      );
    });

    test('Cập nhật thu nhập lỗi: ném lại và không làm người dùng bị đăng xuất', () async {
      await controller.login('test@finmate.com', 'Password123!');
      fakeRepo.updateProfileFails = true;
      await expectLater(controller.updateMonthlyIncome(1000), throwsA(isA<NetworkException>()));
      expect(controller.state.value, isNotNull);
    });
  });

  group('Dọn dữ liệu khi kết thúc phiên', () {
    test('logout và hết phiên đều gọi onSignedOut đúng một lần mỗi lần', () async {
      var calls = 0;
      final repo = FakeAuthRepository();
      final ctrl = AuthController(repository: repo, onSignedOut: () async => calls++);
      await ctrl.login('test@finmate.com', 'Password123!');

      await ctrl.logout();
      expect(calls, 1);
      expect(ctrl.state.value, isNull);

      await ctrl.login('test@finmate.com', 'Password123!');
      ctrl.handleSessionExpired();
      await pumpEventQueue();
      expect(calls, 2);
      expect(ctrl.state.value, isNull);
    });

    test('logout_keeps_unsynced_rows_for_that_user: đăng xuất không xóa giao dịch chưa đồng bộ trên máy', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.insertLocalTransaction(LocalTransactionsCompanion.insert(
        id: 'tx-1',
        clientRequestId: 'req-1',
        amountCents: BigInt.from(45000),
        transactionType: 'Debit',
        status: 'Confirmed',
        financialAccountId: 'acc',
        transactedAt: DateTime(2026, 10, 13),
      ));
      final repo = FakeAuthRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        databaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(authControllerProvider.notifier);
      await ctrl.login('test@finmate.com', 'Password123!');

      await ctrl.logout();

      expect((await db.getAllTransactions()).map((t) => t.id), ['tx-1']);
    });

    test('currentUserIdProvider theo dõi id người dùng đăng nhập', () async {
      final repo = FakeAuthRepository();
      final ctrl = AuthController(repository: repo);
      final container = ProviderContainer(overrides: [authControllerProvider.overrideWith((ref) => ctrl)]);
      addTearDown(container.dispose);

      await ctrl.checkAuthStatus();
      expect(container.read(currentUserIdProvider), isNull);
      await ctrl.login('test@finmate.com', 'Password123!');
      expect(container.read(currentUserIdProvider), 'usr-1');
      await ctrl.logout();
      expect(container.read(currentUserIdProvider), isNull);
    });
  });

  group('Auth guard - authRedirect', () {
    UserProfile user({bool verified = true, int? income, bool terms = true}) => UserProfile(
          id: 'u',
          email: 'a@finmate.com',
          displayName: 'A',
          isEmailVerified: verified,
          monthlyIncomeCents: income,
          termsAccepted: terms,
          notificationPrefs: NotificationPrefs.defaultPrefs(),
          createdAt: DateTime(2026),
        );

    test('đang kiểm tra phiên: giữ nguyên vị trí', () {
      expect(authRedirect(const AsyncValue.loading(), '/splash'), isNull);
      expect(authRedirect(const AsyncValue.loading(), '/home'), isNull);
    });

    test('chưa đăng nhập: splash về Welcome, màn bảo vệ về đăng nhập, màn công khai giữ nguyên', () {
      const guest = AsyncValue<UserProfile?>.data(null);
      expect(authRedirect(guest, '/splash'), '/');
      expect(authRedirect(guest, '/home'), '/login');
      expect(authRedirect(guest, '/profile'), '/login');
      expect(authRedirect(guest, '/login'), isNull);
      expect(authRedirect(guest, '/verify-otp'), isNull);
    });

    test('email chưa xác thực: không vào được màn bảo vệ', () {
      final unverified = AsyncValue<UserProfile?>.data(user(verified: false));
      expect(authRedirect(unverified, '/home'), '/login');
      expect(authRedirect(unverified, '/verify-otp'), isNull);
    });

    test('chưa đồng ý điều khoản: mọi màn đều bị đưa tới /terms, ở /terms thì giữ nguyên', () {
      final fresh = AsyncValue<UserProfile?>.data(user(income: 15000000, terms: false));
      for (final location in ['/splash', '/', '/login', '/home', '/assistant', '/profile', '/onboarding']) {
        expect(authRedirect(fresh, location), '/terms', reason: location);
      }
      expect(authRedirect(fresh, '/terms'), isNull);
    });

    test('đã đồng ý rồi mà còn ở /terms: đi tiếp như người vừa đăng nhập', () {
      expect(authRedirect(AsyncValue<UserProfile?>.data(user(income: 15000000)), '/terms'), '/home');
      expect(authRedirect(AsyncValue<UserProfile?>.data(user()), '/terms'), '/onboarding');
    });

    test('chưa đăng nhập thì /terms không vào được (không có hồ sơ để ghi đồng ý)', () {
      expect(authRedirect(const AsyncValue<UserProfile?>.data(null), '/terms'), '/login');
    });

    test('đã đăng nhập: rời màn dành cho khách, chưa có thu nhập thì vào onboarding', () {
      final needsSetup = AsyncValue<UserProfile?>.data(user());
      final ready = AsyncValue<UserProfile?>.data(user(income: 15000000));
      expect(authRedirect(needsSetup, '/login'), '/onboarding');
      expect(authRedirect(ready, '/'), '/home');
      expect(authRedirect(ready, '/verify-otp'), '/home');
      expect(authRedirect(ready, '/planning'), isNull);
    });
  });

  group('Auth screens', () {
    late FakeAuthRepository repo;
    late AuthController ctrl;

    setUp(() {
      repo = FakeAuthRepository();
      ctrl = AuthController(repository: repo);
    });

    Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => screen),
        GoRoute(path: '/verify-otp', builder: (_, __) => const Text('OTP_PAGE')),
        GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN_PAGE')),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith((ref) => ctrl)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    Future<void> fillAndSubmitRegister(WidgetTester tester, String email) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Nguyen Van A');
      await tester.enterText(fields.at(1), email);
      await tester.enterText(fields.at(2), 'Password123!');
      await tester.enterText(fields.at(3), 'Password123!');
      await tester.tap(find.text('Đăng ký tài khoản'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Đăng ký thất bại: hiện lỗi và KHÔNG chuyển sang màn OTP', (tester) async {
      await pumpScreen(tester, const RegisterScreen());
      await fillAndSubmitRegister(tester, 'dup@finmate.com');

      expect(find.text('Email đã được sử dụng.'), findsOneWidget);
      expect(find.text('OTP_PAGE'), findsNothing);
    });

    testWidgets('Đăng ký thành công: chuyển sang màn OTP', (tester) async {
      await pumpScreen(tester, const RegisterScreen());
      await fillAndSubmitRegister(tester, 'ok@finmate.com');

      expect(find.text('OTP_PAGE'), findsOneWidget);
    });

    testWidgets('OTP: không tự gửi khi đủ 6 số, bấm nhiều lần chỉ gửi một lần', (tester) async {
      await ctrl.register('a@finmate.com', 'Password123!', 'A');
      repo.verifyGate = Completer<void>();
      repo.verifyIssuesTokens = false;

      await pumpScreen(tester, const OtpVerificationScreen(email: 'a@finmate.com'));
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(repo.verifyCalls, 0);

      await tester.tap(find.text('Xác nhận'));
      await tester.pump();
      // Đang gửi: nút đổi thành spinner và bị vô hiệu hóa
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(repo.verifyCalls, 1);

      // Server không cấp token => chuyển về đăng nhập
      repo.verifyGate!.complete();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('Đăng nhập khi email chưa xác thực: chuyển sang màn OTP thay vì hiện lỗi', (tester) async {
      repo.loginError = ApiException(message: 'Email chưa được xác minh.', code: 'AUTH_EMAIL_NOT_VERIFIED', statusCode: 401);
      await pumpScreen(tester, const LoginScreen());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'a@finmate.com');
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('OTP_PAGE'), findsOneWidget);
    });

    testWidgets('OTP sai: hiện thông điệp thân thiện, không lộ ApiException(...)', (tester) async {
      await ctrl.register('a@finmate.com', 'Password123!', 'A');
      await pumpScreen(tester, const OtpVerificationScreen(email: 'a@finmate.com'));

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Xác nhận'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mã xác thực không hợp lệ.'), findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
    });
  });
}
