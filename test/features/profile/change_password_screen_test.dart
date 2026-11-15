import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/change_password_screen.dart';

class _MockAuth extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  _MockAuth(super.state, {this.fail = false});
  final bool fail;
  final calls = <List<String>>[];

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    if (fail) throw Exception('boom');
    calls.add([currentPassword, newPassword]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_MockAuth> pump(WidgetTester tester, {bool fail = false, double width = 390}) async {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _MockAuth(const AsyncValue.data(null), fail: fail);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, __) => const Text('START')),
      GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
      GoRoute(path: '/change', builder: (_, __) => const ChangePasswordScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => auth)],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/change');
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> fill(WidgetTester tester, {String old = 'OldPass1', String neu = 'NewPass1!', String? confirm}) async {
    await tester.enterText(find.byKey(const ValueKey('old-password')), old);
    await tester.enterText(find.byKey(const ValueKey('new-password')), neu);
    await tester.enterText(find.byKey(const ValueKey('confirm-password')), confirm ?? neu);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('change-password-submit')));
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
  }

  test('passwordChecks tính đúng 3 tiêu chí', () {
    expect(passwordChecks('abc').length, isFalse);
    expect(passwordChecks('Abcdefg1').upperAndDigit, isTrue);
    expect(passwordChecks('Abcdefg1!').special, isTrue);
  });

  testWidgets('nhãn độ an toàn đổi theo mật khẩu mới', (tester) async {
    await pump(tester);
    final label = find.byKey(const ValueKey('strength-label'));

    await tester.enterText(find.byKey(const ValueKey('new-password')), 'abc');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).data, 'Yếu');

    await tester.enterText(find.byKey(const ValueKey('new-password')), 'Abcdefg1');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).data, 'Khá mạnh');

    await tester.enterText(find.byKey(const ValueKey('new-password')), 'Abcdefg1!');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).data, 'Mạnh');
  });

  testWidgets('xác nhận không khớp thì báo lỗi và không gọi đổi mật khẩu', (tester) async {
    final auth = await pump(tester);
    await fill(tester, confirm: 'Khac12345');
    await submit(tester);

    expect(find.text('Mật khẩu xác nhận không trùng khớp.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('mật khẩu mới dưới 8 ký tự bị chặn', (tester) async {
    final auth = await pump(tester);
    await fill(tester, neu: 'Ab1!');
    await submit(tester);

    expect(find.text('Mật khẩu mới phải từ 8 ký tự trở lên.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('thành công gửi đúng mật khẩu cũ/mới rồi chuyển về đăng nhập', (tester) async {
    final auth = await pump(tester);
    await fill(tester);
    await submit(tester);

    expect(auth.calls, [
      ['OldPass1', 'NewPass1!']
    ]);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('server từ chối thì ở lại màn', (tester) async {
    await pump(tester, fail: true);
    await fill(tester);
    await submit(tester);

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);
  });

  testWidgets('không tràn bố cục ở 320dp', (tester) async {
    await pump(tester, width: 320);
    await fill(tester);
    expect(tester.takeException(), isNull);
  });
}
