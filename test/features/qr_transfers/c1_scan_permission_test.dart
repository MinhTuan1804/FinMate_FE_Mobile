import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/permissions/permission_service.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c1_scan_qr_screen.dart';
import 'package:finmate/shared/widgets/permission_prompt.dart';

class _FakePermissions implements PermissionService {
  PermissionState current;
  PermissionState afterRequest;
  int requests = 0;
  int settingsOpened = 0;

  _FakePermissions(this.current, {PermissionState? afterRequest}) : afterRequest = afterRequest ?? current;

  @override
  Future<PermissionState> status(AppPermission permission) async => current;

  @override
  Future<PermissionState> request(AppPermission permission) async {
    requests++;
    current = afterRequest;
    return current;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  Future<void> pumpScan(WidgetTester tester, _FakePermissions fake) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [permissionServiceProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: C1ScanQrScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('quét QR chưa có quyền camera: hỏi quyền ngay khi mở, bị từ chối thì hiện khối giải thích + nút Cho phép', (tester) async {
    final fake = _FakePermissions(PermissionState.denied);
    await pumpScan(tester, fake);

    expect(fake.requests, 1);
    expect(find.text('Cần quyền camera để quét QR'), findsOneWidget);
    expect(find.byKey(const ValueKey('permission-request')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('permission-request')));
    await tester.pumpAndSettle();
    expect(fake.requests, 2);
  });

  testWidgets('quét QR bị chặn vĩnh viễn: không hỏi lại, nút Mở Cài đặt mở trang cài đặt của app', (tester) async {
    final fake = _FakePermissions(PermissionState.blocked);
    await pumpScan(tester, fake);

    expect(fake.requests, 0);
    expect(find.text('Cần quyền camera để quét QR'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('permission-open-settings')));
    await tester.pumpAndSettle();
    expect(fake.settingsOpened, 1);
  });

  testWidgets('hộp thoại quyền: "Mở Cài đặt" mở trang cài đặt, "Để sau" thì không', (tester) async {
    final fake = _FakePermissions(PermissionState.blocked);
    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [permissionServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          captured = ref;
          return Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showPermissionSettingsDialog(ctx, captured, title: 'Cần quyền micro', message: 'Hãy bật quyền.'),
                child: const Text('mở'),
              ),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(fake.settingsOpened, 0);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();
    expect(fake.settingsOpened, 1);
  });
}
