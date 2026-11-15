import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/delete_account_screen.dart';
import '../../fixtures/fixture.dart';

class _MockAuth extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  _MockAuth(super.state, {this.fail = false});
  final bool fail;
  String? deletedWith;

  @override
  Future<void> deleteAccount({required String password}) async {
    if (fail) throw Exception('boom');
    deletedWith = password;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('isDeleteConfirmation chấp nhận có/không dấu, không phân biệt hoa thường', () {
    expect(isDeleteConfirmation('XÓA TÀI KHOẢN'), isTrue);
    expect(isDeleteConfirmation(' xoa tai khoan '), isTrue);
    expect(isDeleteConfirmation('xóa'), isFalse);
  });

  Future<_MockAuth> pump(WidgetTester tester, {bool fail = false, double width = 390}) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _MockAuth(const AsyncValue.data(null), fail: fail);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
      GoRoute(path: '/start', builder: (_, __) => const Text('START')),
      GoRoute(path: '/delete', builder: (_, __) => const DeleteAccountScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        apiClientProvider.overrideWithValue(testApiClient(RouteAdapter((o) => respondFixture('accounts')))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/delete');
    await tester.pumpAndSettle();
    return auth;
  }

  Finder submit() => find.byKey(const ValueKey('delete-submit'));
  bool enabled(WidgetTester t) => t.widget<FilledButton>(submit()).onPressed != null;

  Future<void> fillAll(WidgetTester tester, {String phrase = 'XÓA TÀI KHOẢN'}) async {
    await tester.enterText(find.byKey(const ValueKey('delete-phrase')), phrase);
    await tester.enterText(find.byKey(const ValueKey('delete-password')), 'Secret123');
    await tester.tap(find.byKey(const ValueKey('delete-ack')));
    await tester.pumpAndSettle();
  }

  testWidgets('nút xóa chỉ bật khi đủ cụm từ, mật khẩu và tick xác nhận', (tester) async {
    await pump(tester);
    expect(enabled(tester), isFalse);

    await fillAll(tester, phrase: 'xoa');
    expect(enabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('delete-phrase')), 'xoa tai khoan');
    await tester.pumpAndSettle();
    expect(enabled(tester), isTrue);
  });

  testWidgets('xóa thành công gọi deleteAccount với mật khẩu rồi về trang chủ', (tester) async {
    final auth = await pump(tester);
    await fillAll(tester);

    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(auth.deletedWith, 'Secret123');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('lỗi từ server thì ở lại màn và nút bật lại', (tester) async {
    await pump(tester, fail: true);
    await fillAll(tester);

    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(enabled(tester), isTrue);
  });

  testWidgets('không tràn bố cục ở 320dp', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
