import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/presentation/screens/community_screen.dart';
import '../../fixtures/fixture.dart';

GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const CommunityScreen()),
      GoRoute(path: '/community-post', builder: (c, s) => const Scaffold(body: Text('POST_DETAIL'))),
      GoRoute(path: '/community-places', builder: (c, s) => const Scaffold(body: Text('PLACES'))),
      GoRoute(path: '/community-profile', builder: (c, s) => const Scaffold(body: Text('PROFILE'))),
    ]);

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: MaterialApp.router(routerConfig: _router()),
  ));
  await tester.pumpAndSettle();
}

RouteAdapter _feedAdapter({String postsFixture = 'community_posts'}) => RouteAdapter((o) {
      if (o.path.contains('/topics')) return respondFixture('community_topics');
      return respondFixture(postsFixture);
    });

void main() {
  group('CommunityScreen', () {
    testWidgets('hiện danh sách bài, ẩn bài "chạm quán" không nội dung', (tester) async {
      await _pump(tester, _feedAdapter());

      expect(find.byKey(const ValueKey('community-post-11111111-1111-1111-1111-111111111111')), findsOneWidget);
      expect(find.byKey(const ValueKey('community-post-22222222-2222-2222-2222-222222222222')), findsOneWidget);
    });

    testWidgets('bảng tin rỗng hiện thông báo', (tester) async {
      await _pump(tester, _feedAdapter(postsFixture: 'community_posts_empty'));
      expect(find.text('Chưa có bài nào.'), findsOneWidget);
    });

    testWidgets('bấm 1 bài thì mở màn chi tiết', (tester) async {
      await _pump(tester, _feedAdapter());

      await tester.tap(find.byKey(const ValueKey('community-post-11111111-1111-1111-1111-111111111111')));
      await tester.pumpAndSettle();

      expect(find.text('POST_DETAIL'), findsOneWidget);
    });

    testWidgets('đăng bài mới gửi đúng topic/body rồi mở màn chi tiết', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/topics')) return respondFixture('community_topics');
        if (o.method == 'POST') return respondFixture('community_post_created', status: 201);
        return respondFixture('community_posts_empty');
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('community-create-post')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('community-post-body')),
          'Có ai biết app nào theo dõi chi tiêu tốt không?');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng'));
      await tester.pumpAndSettle();

      final createReq = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(createReq.data['body'], 'Có ai biết app nào theo dõi chi tiêu tốt không?');
      expect(find.text('POST_DETAIL'), findsOneWidget);
    });

    testWidgets('bấm icon quán/hồ sơ thì điều hướng đúng màn', (tester) async {
      await _pump(tester, _feedAdapter(postsFixture: 'community_posts_empty'));

      await tester.tap(find.byKey(const ValueKey('community-open-places')));
      await tester.pumpAndSettle();
      expect(find.text('PLACES'), findsOneWidget);
    });
  });
}
