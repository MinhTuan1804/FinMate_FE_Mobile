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

    testWidgets('tạo yêu cầu mới gửi đúng category/subject/body rồi mở màn chi tiết', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.method == 'POST') return respondFixture('support_ticket_detail', status: 201);
        return respondFixture('support_tickets_empty');
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('support-create')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('support-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giao dịch').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('support-subject')), 'Giao dịch bị trùng');
      await tester.enterText(find.byKey(const ValueKey('support-body')), 'Nội dung');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi'));
      await tester.pumpAndSettle();

      final createReq = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(createReq.data, {'category': 'Transaction', 'subject': 'Giao dịch bị trùng', 'body': 'Nội dung'});
      expect(find.text('TICKET_DETAIL'), findsOneWidget);
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
