import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/support/presentation/screens/support_access_log_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_screen.dart';
import '../../fixtures/fixture.dart';

GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const SupportScreen()),
      GoRoute(path: '/support-ticket', builder: (c, s) => const Scaffold(body: Text('TICKET_DETAIL'))),
      GoRoute(path: '/support-access-log', builder: (c, s) => const SupportAccessLogScreen()),
    ]);

Future<void> _pump(WidgetTester tester, RouteAdapter adapter, {GoRouter? router}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: MaterialApp.router(routerConfig: router ?? _router()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('SupportScreen', () {
    testWidgets('danh sách rỗng hiện thông báo chưa có yêu cầu', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('support_tickets_empty')));
      expect(find.text('Bạn chưa có yêu cầu hỗ trợ nào.'), findsOneWidget);
    });

    testWidgets('hiện đủ danh sách ca hỗ trợ', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('support_tickets_list')));
      expect(find.text('Giao dịch bị trùng'), findsOneWidget);
      expect(find.text('Không đăng nhập được'), findsOneWidget);
    });

    testWidgets('chip trạng thái đếm đúng và lọc; ô tìm kiếm lọc theo tiêu đề', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('support_tickets_list')));
      expect(find.text('Tất cả 2'), findsOneWidget);
      expect(find.text('Đang xử lý 1'), findsOneWidget); // ca "New"
      expect(find.text('Đã xong 1'), findsOneWidget); // ca "Resolved"

      await tester.tap(find.byKey(const ValueKey('support-filter-done')));
      await tester.pumpAndSettle();
      expect(find.text('Không đăng nhập được'), findsOneWidget);
      expect(find.text('Giao dịch bị trùng'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('support-filter-all')));
      await tester.enterText(find.byKey(const ValueKey('support-search')), 'trùng');
      await tester.pumpAndSettle();
      expect(find.text('Giao dịch bị trùng'), findsOneWidget);
      expect(find.text('Không đăng nhập được'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('support-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Không có yêu cầu phù hợp.'), findsOneWidget);
    });

    testWidgets('nút tạo yêu cầu mở màn gửi yêu cầu mới (/support/new)', (tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const SupportScreen()),
        GoRoute(path: '/support/new', builder: (c, s) => const Scaffold(body: Text('CREATE_PAGE'))),
      ]);
      await _pump(tester, RouteAdapter((o) => respondFixture('support_tickets_empty')), router: router);

      await tester.tap(find.byKey(const ValueKey('support-create')));
      await tester.pumpAndSettle();

      expect(find.text('CREATE_PAGE'), findsOneWidget);
    });

    testWidgets('bấm icon nhật ký truy cập mở đúng màn access-log', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('access-log')) return respondFixture('support_access_log');
        return respondFixture('support_tickets_empty');
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('support-access-log')));
      await tester.pumpAndSettle();

      expect(find.text('Nhật ký truy cập'), findsOneWidget);
      expect(find.textContaining('Ca #aaaaaaaa'), findsWidgets);
    });
  });
}
