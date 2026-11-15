import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/onboarding/presentation/screens/notification_permission_screen.dart';

const _notificationsChannel = MethodChannel('com.example.finmate/notifications');

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Không có app thật phía sau kênh này trong widget test — trả null ngay để
  // _enable() không treo chờ một lời gọi platform channel không ai trả lời.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    _notificationsChannel,
    (call) async => null,
  );
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_notificationsChannel, null));
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const NotificationPermissionScreen()),
      GoRoute(path: '/survey', builder: (context, state) => const Scaffold(body: Text('Khảo sát'))),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  group('NotificationPermissionScreen', () {
    testWidgets('bấm Cấp quyền thì điều hướng sang /survey', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('notif-permission-enable')));
      await tester.pumpAndSettle();

      expect(find.text('Khảo sát'), findsOneWidget);
    });

    testWidgets('bấm Bỏ qua thì điều hướng sang /survey', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('notif-permission-skip')));
      await tester.pumpAndSettle();

      expect(find.text('Khảo sát'), findsOneWidget);
    });
  });
}
