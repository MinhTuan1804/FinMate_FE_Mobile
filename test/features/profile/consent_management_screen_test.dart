import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/domain/community.dart';
import 'package:finmate/features/community/presentation/controllers/community_controller.dart';
import 'package:finmate/features/profile/presentation/screens/consent_management_screen.dart';
import '../auth/consent_fakes.dart';

void main() {
  Future<void> pump(WidgetTester tester, ConsentRepo repo) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthController(repository: repo);
    await auth.checkAuthStatus();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        // Trạng thái Cộng đồng đọc từ API riêng: giữ ở trạng thái đang tải thay vì gọi mạng thật.
        communityProfileProvider.overrideWith((ref) => Completer<CommunityProfileEntity>().future),
      ],
      child: const MaterialApp(home: ConsentManagementScreen()),
    ));
    await tester.pumpAndSettle();
  }

  bool isOn(WidgetTester tester, String key) => tester.widget<Switch>(find.byKey(ValueKey(key))).value;

  testWidgets('chỉ hiện 3 quyền thật, trạng thái lấy từ hồ sơ; điều khoản không tắt được', (tester) async {
    await pump(tester, ConsentRepo(consentTestUser(terms: true, ai: true)));

    expect(find.byType(Switch), findsNWidgets(4)); // điều khoản, AI, huấn luyện, cộng đồng (chỉ đọc)
    expect(tester.widget<Switch>(find.byKey(const ValueKey('consent-community'))).onChanged, isNull);
    expect(find.text('Bắt buộc'), findsOneWidget);
    expect(find.text('Bản v${ConsentVersions.terms}'), findsOneWidget);
    expect(isOn(tester, 'consent-terms'), isTrue);
    expect(isOn(tester, 'consent-ai'), isTrue);
    expect(isOn(tester, 'consent-training'), isFalse);
    expect(tester.widget<Switch>(find.byKey(const ValueKey('consent-terms'))).onChanged, isNull);
  });

  testWidgets('tắt AI gọi withdraw rồi công tắc tắt theo hồ sơ mới', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true));
    await pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('consent-ai')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['withdraw:ai']);
    expect(isOn(tester, 'consent-ai'), isFalse);
  });

  testWidgets('rút đóng góp huấn luyện phải xác nhận; hủy thì không gọi server', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true, training: true));
    await pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('consent-training')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(isOn(tester, 'consent-training'), isTrue);

    await tester.tap(find.byKey(const ValueKey('consent-training')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rút lại và xóa'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['withdraw:training']);
    expect(isOn(tester, 'consent-training'), isFalse);
  });

  testWidgets('server lỗi thì công tắc giữ nguyên và hiện thông báo lỗi', (tester) async {
    final repo = ConsentRepo(consentTestUser(terms: true, ai: true))..failNext = true;
    await pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('consent-ai')));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được, thử lại nhé'), findsOneWidget);
    expect(isOn(tester, 'consent-ai'), isTrue);
  });
}
