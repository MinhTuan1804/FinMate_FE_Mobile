import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/backup_export_screen.dart';
import '../../fixtures/fixture.dart';

class _MockAuth extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  _MockAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late List<String> requests;
  late List<Map<String, dynamic>> exports;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    requests = [];
    exports = [];
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final user = UserProfile(
      id: 'u1',
      email: 'probe@example.com',
      displayName: 'Probe',
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _MockAuth(AsyncValue.data(user))),
        databaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(testApiClient(RouteAdapter((o) {
          requests.add('${o.method} ${o.path}');
          if (o.path.contains('/exports/personal-data')) return respondJson({'success': true, 'data': exports});
          return respondFixture('accounts');
        }))),
      ],
      child: const MaterialApp(home: BackupExportScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện email, số ví thật và trạng thái đã đồng bộ khi không còn giao dịch chờ', (tester) async {
    await pump(tester);

    expect(find.text('probe@example.com'), findsOneWidget);
    expect(find.text('ĐÃ ĐỒNG BỘ AN TOÀN'), findsOneWidget);
    expect(find.textContaining('Tất cả tài khoản & ví ('), findsOneWidget);
    expect(find.text('Chưa có bản sao lưu nào'), findsOneWidget);
  });

  testWidgets('còn giao dịch chờ gửi thì báo đúng số lượng', (tester) async {
    await db.enqueueSync(SyncQueueCompanion.insert(clientRequestId: 'x', endpoint: '/e', payload: '{}', createdAt: DateTime.now()));
    await pump(tester);

    expect(find.text('1 GIAO DỊCH CHỜ ĐỒNG BỘ'), findsOneWidget);
  });

  testWidgets('sao lưu tự động vẫn khóa; xuất CSV và gói dữ liệu cá nhân dùng được', (tester) async {
    await pump(tester);

    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('backup-now'))).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('export-run'))).onPressed, isNotNull);
    expect(find.text('Bạn chưa yêu cầu gói dữ liệu nào.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('personal-data-request'))).onPressed, isNotNull);
  });

  testWidgets('gói dữ liệu đang chuẩn bị thì khóa nút yêu cầu; sẵn sàng thì có nút tải', (tester) async {
    exports = [{'id': 'e1', 'status': 'Running'}];
    await pump(tester);
    expect(find.textContaining('Đang chuẩn bị'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('personal-data-request'))).onPressed, isNull);

    exports = [{'id': 'e1', 'status': 'Ready', 'expiresAt': '2026-11-30T03:00:00Z'}];
    await pump(tester);
    expect(find.byKey(const ValueKey('personal-data-download')), findsOneWidget);
  });

  testWidgets('ở 320dp không tràn bố cục', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
