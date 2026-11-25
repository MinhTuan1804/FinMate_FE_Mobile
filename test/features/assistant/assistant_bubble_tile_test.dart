import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_bubble_bridge.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_bubble_tile.dart';

/// Giả lập phía Android của bong bóng FinMate AI (bubble/AssistantBubbleChannel.kt).
class _FakeAndroid {
  bool permission;
  bool bubblesAllowed;
  bool grantOnRequest;
  bool showing = false;
  String mode = 'system';
  bool overlayPermission = false;
  final calls = <String>[];

  _FakeAndroid({this.permission = true, this.bubblesAllowed = true, this.grantOnRequest = true});

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'status':
        return {
          'supported': true,
          'mode': mode,
          'notificationPermission': permission,
          'bubblesAllowed': bubblesAllowed,
          'overlayPermission': overlayPermission,
          'showing': showing,
        };
      case 'requestNotificationPermission':
        permission = grantOnRequest;
        return grantOnRequest;
      case 'show':
        showing = mode == 'overlay' ? overlayPermission : permission;
        return showing;
      case 'hide':
        showing = false;
        return null;
    }
    return null;
  }
}

void main() {
  const channel = MethodChannel('com.finmate.app/assistant_bubble');

  Future<_FakeAndroid> pump(WidgetTester tester, _FakeAndroid android) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, android.handle);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(ProviderScope(
      overrides: [assistantBubbleBridgeProvider.overrideWithValue(AssistantBubbleBridge(channel))],
      child: const MaterialApp(home: Scaffold(body: AssistantBubbleTile())),
    ));
    await tester.pumpAndSettle();
    return android;
  }

  bool switchValue(WidgetTester tester) => tester.widget<Switch>(find.byKey(const ValueKey('assistant-bubble-switch'))).value;

  testWidgets('bật: xin quyền thông báo rồi hiện bong bóng, công tắc chuyển sang bật', (tester) async {
    final android = await pump(tester, _FakeAndroid(permission: false));
    expect(switchValue(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('assistant-bubble-tile')));
    await tester.pumpAndSettle();

    expect(android.calls, containsAllInOrder(['requestNotificationPermission', 'show']));
    expect(switchValue(tester), isTrue);
  });

  testWidgets('từ chối quyền thông báo: không hiện bong bóng và báo lý do', (tester) async {
    final android = await pump(tester, _FakeAndroid(permission: false, grantOnRequest: false));

    await tester.tap(find.byKey(const ValueKey('assistant-bubble-tile')));
    await tester.pumpAndSettle();

    expect(android.calls, isNot(contains('show')));
    expect(find.textContaining('Cần cho phép FinMate gửi thông báo'), findsOneWidget);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('bong bóng đang tắt trong cài đặt Android: mở cài đặt, quay lại đã bật thì hiện bong bóng', (tester) async {
    final android = await pump(tester, _FakeAndroid(bubblesAllowed: false));

    await tester.tap(find.byKey(const ValueKey('assistant-bubble-tile')));
    await tester.pumpAndSettle();
    expect(android.calls, contains('openBubbleSettings'));
    expect(android.calls, isNot(contains('show')));

    android.bubblesAllowed = true; // người dùng bật trong cài đặt rồi quay lại
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(android.calls, contains('show'));
    expect(switchValue(tester), isTrue);
  });

  testWidgets('máy MIUI (overlay): chưa có quyền vẽ đè thì mở màn cấp quyền, quay lại có quyền thì hiện bong bóng', (tester) async {
    final android = _FakeAndroid(permission: false)..mode = 'overlay';
    await pump(tester, android);

    await tester.tap(find.byKey(const ValueKey('assistant-bubble-tile')));
    await tester.pumpAndSettle();
    expect(android.calls, contains('openOverlaySettings'));
    // Chế độ overlay không cần quyền thông báo.
    expect(android.calls, isNot(contains('requestNotificationPermission')));
    expect(android.calls, isNot(contains('show')));

    android.overlayPermission = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(android.calls, contains('show'));
    expect(switchValue(tester), isTrue);
  });

  testWidgets('tắt: gỡ bong bóng', (tester) async {
    final android = _FakeAndroid()..showing = true;
    await pump(tester, android);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('assistant-bubble-switch')));
    await tester.pumpAndSettle();

    expect(android.calls, contains('hide'));
    expect(switchValue(tester), isFalse);
  });

  test('không có kênh native (iOS/test) thì coi như không hỗ trợ', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final status = await AssistantBubbleBridge(const MethodChannel('missing/channel')).status();
    expect(status.supported, isFalse);
  });
}
