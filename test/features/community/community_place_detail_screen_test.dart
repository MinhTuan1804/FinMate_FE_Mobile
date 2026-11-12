import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/presentation/screens/community_place_detail_screen.dart';
import '../../fixtures/fixture.dart';

const _placeId = '33333333-3333-3333-3333-333333333333';

GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const CommunityPlaceDetailScreen(placeId: _placeId)),
      GoRoute(path: '/community-post', builder: (c, s) => const Scaffold(body: Text('POST_DETAIL'))),
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

void main() {
  group('CommunityPlaceDetailScreen', () {
    testWidgets('hiện thông tin quán và bài liên quan', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('community_place_detail')));

      expect(find.text('Bún bò Huế Cô Ba'), findsOneWidget);
      expect(find.byKey(const ValueKey('community-place-post-22222222-2222-2222-2222-222222222222')), findsOneWidget);
    });

    testWidgets('bấm bài liên quan (không phải chạm quán) thì mở chi tiết', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('community_place_detail')));

      await tester.tap(find.byKey(const ValueKey('community-place-post-22222222-2222-2222-2222-222222222222')));
      await tester.pumpAndSettle();

      expect(find.text('POST_DETAIL'), findsOneWidget);
    });
  });
}
