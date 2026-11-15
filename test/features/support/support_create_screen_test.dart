import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/support/data/support_image_source.dart';
import 'package:finmate/features/support/presentation/screens/support_create_screen.dart';
import '../../fixtures/fixture.dart';

class _FakeImages implements SupportImageSource {
  @override
  Future<PickedImage?> pickFromGallery() async => const PickedImage(path: 'test/fixtures/receipt_sample.png', name: 'loi.png');
}

void main() {
  Future<RouteAdapter> pump(WidgetTester tester, {RouteAdapter? adapter}) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final a = adapter ??
        RouteAdapter((o) {
          if (o.method == 'POST' && o.path.endsWith('/tickets')) return respondFixture('support_ticket_detail', status: 201);
          if (o.method == 'POST') return respondFixture('support_attachment', status: 201);
          return respondFixture('support_tickets_empty');
        });
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, __) => const Text('START')),
      GoRoute(path: '/support/new', builder: (_, __) => const SupportCreateScreen()),
      GoRoute(path: '/support-ticket', builder: (_, state) => Text('TICKET ${state.extra}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(testApiClient(a)),
        supportImageSourceProvider.overrideWithValue(_FakeImages()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/support/new');
    await tester.pumpAndSettle();
    return a;
  }

  testWidgets('thiếu tiêu đề và nội dung thì báo lỗi tại ô và không gọi server', (tester) async {
    final adapter = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tiêu đề.'), findsOneWidget);
    expect(find.text('Vui lòng nhập nội dung.'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('gửi đúng loại/tiêu đề/nội dung rồi mở chi tiết yêu cầu vừa tạo', (tester) async {
    final adapter = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('support-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giao dịch').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('support-subject')), '  Giao dịch bị trùng  ');
    await tester.enterText(find.byKey(const ValueKey('support-body')), 'Nội dung chi tiết');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    final create = adapter.requests.firstWhere((r) => r.method == 'POST');
    expect(create.data, {'category': 'Transaction', 'subject': 'Giao dịch bị trùng', 'body': 'Nội dung chi tiết'});
    expect(find.textContaining('TICKET '), findsOneWidget);
  });

  testWidgets('thêm ảnh hiện trong danh sách, bỏ được; có ảnh thì tải lên sau khi tạo', (tester) async {
    final adapter = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('add-image')));
    await tester.pumpAndSettle();
    expect(find.text('loi.png'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove-image-0')));
    await tester.pumpAndSettle();
    expect(find.text('loi.png'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-image')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('support-subject')), 'Lỗi');
    await tester.enterText(find.byKey(const ValueKey('support-body')), 'Có ảnh');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    // Đọc tệp ảnh là IO thật: cho tạo yêu cầu xong, rồi nhường event loop thật cho việc đọc tệp, rồi bơm tiếp.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    }
    await tester.pumpAndSettle();

    expect(adapter.requests.where((r) => r.method == 'POST' && r.path.contains('/attachments')), hasLength(1));
  });

  testWidgets('server từ chối thì ở lại màn và không chuyển trang', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') throwNetworkDown(o);
      return respondFixture('support_tickets_empty');
    });
    await pump(tester, adapter: adapter);

    await tester.enterText(find.byKey(const ValueKey('support-subject')), 'Lỗi');
    await tester.enterText(find.byKey(const ValueKey('support-body')), 'Nội dung');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(SupportCreateScreen), findsOneWidget);
    expect(find.textContaining('TICKET '), findsNothing);
  });
}
