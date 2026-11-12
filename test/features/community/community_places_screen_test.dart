import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/presentation/screens/community_places_screen.dart';
import '../../fixtures/fixture.dart';

GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const CommunityPlacesScreen()),
      GoRoute(path: '/community-place', builder: (c, s) => const Scaffold(body: Text('PLACE_DETAIL'))),
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
  group('CommunityPlacesScreen', () {
    testWidgets('hiện danh sách quán với điểm và giá điển hình', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('community_places')));

      expect(find.byKey(const ValueKey('community-place-33333333-3333-3333-3333-333333333333')), findsOneWidget);
      expect(find.textContaining('Chia sẻ: 5'), findsOneWidget);
    });

    testWidgets('chưa có quán nào hiện thông báo trống', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondJson({
            'success': true,
            'data': {'items': [], 'nextCursor': null},
            'error': null,
            'meta': null,
          })));

      expect(find.text('Chưa có quán nào.'), findsOneWidget);
    });

    testWidgets('bấm 1 quán thì mở màn chi tiết', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('community_places')));

      await tester.tap(find.byKey(const ValueKey('community-place-33333333-3333-3333-3333-333333333333')));
      await tester.pumpAndSettle();

      expect(find.text('PLACE_DETAIL'), findsOneWidget);
    });
  });
}
