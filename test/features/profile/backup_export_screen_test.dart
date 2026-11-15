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

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
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
        apiClientProvider.overrideWithValue(testApiClient(RouteAdapter((o) => respondFixture('accounts')))),
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

  testWidgets('nút sao lưu và xuất bị khóa, không giả lập thành công; chọn định dạng đổi nhãn nút', (tester) async {
    await pump(tester);

    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('backup-now'))).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('export-run'))).onPressed, isNull);
    expect(find.text('Xuất và tải về (Excel)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('format-pdf')));
    await tester.pumpAndSettle();
    expect(find.text('Xuất và tải về (PDF)'), findsOneWidget);
    expect(find.textContaining('thành công'), findsNothing);
  });

  testWidgets('ở 320dp không tràn bố cục', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
