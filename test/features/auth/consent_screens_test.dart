import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/training_consent_screen.dart';
import 'package:finmate/features/auth/presentation/screens/terms_consent_screen.dart';
import 'consent_fakes.dart';

/// Màn đồng ý: điều khoản chung (bắt buộc để vào app, đã gồm việc gửi tên món cho AI) và đóng góp dữ liệu huấn luyện (riêng, tùy chọn).
void main() {
  Future<void> pump(WidgetTester tester, ConsentRepo repo, Widget home) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthController(repository: repo);
    await auth.checkAuthStatus(); // như app thật: hồ sơ đã nạp xong trước khi người dùng thấy màn nào
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => auth)],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  /// TermsConsentScreen tự điều hướng sang /ai-consent khi đồng ý xong, nên cần GoRouter thật trong context.
  Future<void> pumpTerms(WidgetTester tester, ConsentRepo repo) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthController(repository: repo);
    await auth.checkAuthStatus();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const TermsConsentScreen()),
      GoRoute(path: '/ai-consent', builder: (_, __) => const Text('AI_CONSENT_PAGE')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => auth)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  group('màn Điều khoản và Quyền riêng tư', () {
    testWidgets('nói rõ 3 nguyên tắc chính; nút Đồng ý chỉ bấm được sau khi tick đồng ý', (tester) async {
      final repo = ConsentRepo(consentTestUser());
      await pumpTerms(tester, repo);

      expect(find.text('Trước khi bắt đầu'), findsOneWidget);
      expect(find.text('Bảo mật cấp ngân hàng'), findsOneWidget);
      expect(find.text('Không chia sẻ bên thứ ba'), findsOneWidget);
      expect(find.text('Quyền kiểm soát thuộc về bạn'), findsOneWidget);

      final button = find.widgetWithText(ElevatedButton, 'Đồng ý & Tiếp tục');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    });

    testWidgets('toàn văn (mở qua liên kết) nêu rõ việc gửi tên món cho AI: gửi gì, không gửi gì, ai nhận, và tắt ở đâu', (tester) async {
      final repo = ConsentRepo(consentTestUser());
      await pumpTerms(tester, repo);

      await tester.tap(find.textContaining('Xem toàn văn'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Phân loại chi tiêu bằng AI'), findsOneWidget);
      expect(find.textContaining('Google Gemini'), findsWidgets);
      expect(find.textContaining('OpenRouter'), findsWidgets);
      expect(find.textContaining('tên món'), findsWidgets);
      expect(find.textContaining('Không gửi'), findsOneWidget); // giá tiền, ảnh, âm thanh, tài khoản; thuốc không bao giờ gửi
      expect(find.textContaining('Cá nhân'), findsWidgets); // chỉ chỗ tắt trong Hồ sơ
      expect(find.textContaining('đóng góp dữ liệu'), findsNothing); // dữ liệu huấn luyện luôn là lựa chọn riêng, không gộp vào điều khoản
      expect(find.textContaining('Chúng tôi không bán dữ liệu của bạn'), findsOneWidget);
      expect(find.textContaining('lưu trên điện thoại của bạn'), findsOneWidget);
    });

    testWidgets('tick rồi Đồng ý & Tiếp tục: ghi đồng ý điều khoản đúng một lần rồi sang /ai-consent (không có lời gọi nào khác)', (tester) async {
      final repo = ConsentRepo(consentTestUser());
      await pumpTerms(tester, repo);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đồng ý & Tiếp tục'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['accept:terms']);
      expect(repo.user.aiConsentGranted, isTrue); // server tự bật AI khi đồng ý Điều khoản
      expect(repo.user.trainingConsentGranted, isFalse);
      expect(find.text('AI_CONSENT_PAGE'), findsOneWidget);
    });

    testWidgets('lỗi mạng: hiện lỗi, không coi là đã đồng ý, bấm lại được', (tester) async {
      final repo = ConsentRepo(consentTestUser())..failNext = true;
      await pumpTerms(tester, repo);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đồng ý & Tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.text('Không lưu được, thử lại nhé'), findsOneWidget);
      expect(repo.user.termsAccepted, isFalse);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Đồng ý & Tiếp tục')).onPressed, isNotNull);
    });
  });

  group('màn đồng ý đóng góp dữ liệu huấn luyện (ensureTrainingConsent)', () {
    bool? result;

    Widget host() => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await ensureTrainingConsent(context, ref),
                child: const Text('bật'),
              ),
            ),
          ),
        );

    Future<void> open(WidgetTester tester, ConsentRepo repo) async {
      await pump(tester, repo, host());
      await tester.tap(find.text('bật'));
      await tester.pumpAndSettle();
    }

    setUp(() => result = null);

    testWidgets('đã đồng ý rồi: trả true ngay, không hiện màn', (tester) async {
      await pump(tester, ConsentRepo(consentTestUser(terms: true, training: true)), host());

      await tester.tap(find.text('bật'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Đóng góp dữ liệu để cải thiện phân loại'), findsNothing);
    });

    testWidgets('nói thật những gì được lưu, không lưu, ở đâu, bao lâu và cách rút lại', (tester) async {
      await open(tester, ConsentRepo(consentTestUser(terms: true)));

      expect(find.text('Đóng góp dữ liệu để cải thiện phân loại'), findsOneWidget);
      expect(find.textContaining('đã ẩn số điện thoại, số tài khoản, email và địa chỉ'), findsOneWidget);
      expect(find.textContaining('ảnh hóa đơn, âm thanh'), findsOneWidget);
      expect(find.textContaining('có thể còn sót'), findsOneWidget); // nói thật rằng tên người chưa được ẩn hết
      expect(find.textContaining('vẫn nối được về tài khoản của bạn'), findsOneWidget);
      expect(find.textContaining('không chia sẻ cho bên thứ ba'), findsOneWidget);
      expect(find.textContaining('bị xóa sau 7 ngày'), findsOneWidget);
      expect(find.textContaining('dữ liệu bạn đã đóng góp sẽ bị xóa'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Đồng ý và tiếp tục')).onPressed, isNull); // phải tick trước
    });

    testWidgets('tick rồi đồng ý: ghi đồng ý training và trả true', (tester) async {
      final repo = ConsentRepo(consentTestUser(terms: true));
      await open(tester, repo);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Đồng ý và tiếp tục'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['accept:training']);
      expect(result, isTrue);
    });

    testWidgets('"Để sau": trả false và không ghi gì', (tester) async {
      final repo = ConsentRepo(consentTestUser(terms: true));
      await open(tester, repo);

      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(repo.calls, isEmpty);
    });

    testWidgets('lỗi mạng khi ghi: ở lại màn, hiện lỗi, chưa coi là đã đồng ý', (tester) async {
      final repo = ConsentRepo(consentTestUser(terms: true))..failNext = true;
      await open(tester, repo);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Đồng ý và tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.text('Không lưu được, thử lại nhé'), findsOneWidget);
      expect(result, isNull);
      expect(repo.user.trainingConsentGranted, isFalse);
    });
  });
}
