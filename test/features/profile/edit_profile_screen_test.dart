import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/edit_profile_screen.dart';

class _MockAuth extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  _MockAuth(super.state);

  final calls = <({String name, int? income})>[];
  Object? failWith;

  @override
  Future<void> updateProfile({required String displayName, int? monthlyIncomeCents}) async {
    if (failWith != null) throw failWith!;
    calls.add((name: displayName, income: monthlyIncomeCents));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final user = UserProfile(
    id: 'u1',
    email: 'probe@example.com',
    displayName: 'Probe',
    monthlyIncomeCents: 35000000,
    isEmailVerified: true,
    notificationPrefs: NotificationPrefs.defaultPrefs(),
    createdAt: DateTime(2026),
  );

  Future<_MockAuth> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _MockAuth(AsyncValue.data(user));
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => auth)],
      child: const MaterialApp(home: EditProfileScreen()),
    ));
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('hiện tên, email chỉ đọc và thu nhập có dấu phân cách từ hồ sơ; không có ô số điện thoại', (tester) async {
    await pump(tester);

    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Probe'), findsOneWidget);
    expect(find.text('probe@example.com'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '35.000.000'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsNothing);
  });

  testWidgets('lưu gửi tên đã cắt khoảng trắng và thu nhập là số nguyên đồng', (tester) async {
    final auth = await pump(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Probe'), '  Nguyễn Văn A  ');
    await tester.enterText(find.byKey(const ValueKey('income-field')), '20.000.000');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(auth.calls, [(name: 'Nguyễn Văn A', income: 20000000)]);
  });

  testWidgets('tên rỗng hoặc thu nhập sai thì báo lỗi tại ô và không gọi server', (tester) async {
    final auth = await pump(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Probe'), '');
    await tester.enterText(find.byKey(const ValueKey('income-field')), 'abc');
    await tester.tap(find.byKey(const ValueKey('save-top')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập họ và tên.'), findsOneWidget);
    expect(find.text('Số tiền không hợp lệ.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('server từ chối thì hiện thông điệp lỗi và ở lại màn', (tester) async {
    final auth = await pump(tester);
    auth.failWith = ApiException(message: 'Không lưu được hồ sơ', statusCode: 500);

    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được hồ sơ'), findsOneWidget);
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
  });
}
