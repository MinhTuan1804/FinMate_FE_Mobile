import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/presentation/screens/community_profile_screen.dart';
import '../../fixtures/fixture.dart';
import '../auth/consent_fakes.dart';

Future<void> _pump(WidgetTester tester, RouteAdapter adapter, {ConsentRepo? authRepo}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  AuthController? auth;
  if (authRepo != null) {
    auth = AuthController(repository: authRepo);
    await auth.checkAuthStatus();
  }
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
      if (auth != null) authControllerProvider.overrideWith((ref) => auth!),
    ],
    child: const MaterialApp(home: CommunityProfileScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('CommunityProfileScreen', () {
    testWidgets('đã đồng ý thì hiện trạng thái, tỉnh/khu vực và công tắc gợi ý', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/regions')) return respondFixture('community_regions');
        return respondFixture('community_profile');
      });
      await _pump(tester, adapter);

      expect(find.text('Đã đồng ý tham gia'), findsOneWidget);
      expect(find.byKey(const ValueKey('community-prompts-switch')), findsOneWidget);
    });

    testWidgets('chưa đồng ý thì hiện nút đồng ý tham gia, bấm gọi acceptConsent(community)', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/regions')) return respondFixture('community_regions');
        return respondFixture('community_profile_no_consent');
      });
      final authRepo = ConsentRepo(consentTestUser());
      await _pump(tester, adapter, authRepo: authRepo);

      expect(find.text('Chưa đồng ý tham gia'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('community-grant-consent')));
      await tester.pumpAndSettle();

      expect(authRepo.calls, contains('accept:community'));
    });

    testWidgets('lưu hồ sơ gửi đúng provinceCode/areaCode/promptsEnabled', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/regions')) return respondFixture('community_regions');
        if (o.method == 'PATCH') return respondFixture('community_profile_updated');
        return respondFixture('community_profile');
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('community-province-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hà Nội').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('community-area-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn Kiếm').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('community-save-profile')));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.method == 'PATCH');
      expect(req.data, {'provinceCode': 'HN', 'areaCode': 'HK', 'promptsEnabled': true});
      expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
    });
  });
}
