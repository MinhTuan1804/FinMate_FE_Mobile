import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/features/dashboard/presentation/widgets/app_bottom_nav.dart';

Widget _app(GoRouter router) => MaterialApp.router(routerConfig: router);

GoRouter _router({int currentIndex = 0}) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => Scaffold(body: const Text('HOME'), bottomNavigationBar: AppBottomNav(currentIndex: currentIndex))),
        GoRoute(path: '/transactions', builder: (_, __) => const Scaffold(body: Text('SO THU CHI'))),
        GoRoute(path: '/planning', builder: (_, __) => const Scaffold(body: Text('KE HOACH'))),
        GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('CA NHAN'))),
        GoRoute(path: '/qr-scan', builder: (_, __) => const Scaffold(body: Text('QUET QR'))),
      ],
    );

void main() {
  testWidgets('có bốn tab có nhãn chữ và nút quét QR ở GIỮA', (tester) async {
    await tester.pumpWidget(_app(_router()));

    for (final label in ['Trang chủ', 'Sổ thu chi', 'Kế hoạch', 'Cá nhân']) {
      expect(find.text(label), findsOneWidget);
    }
    final scan = find.byIcon(LucideIcons.scanQrCode);
    expect(scan, findsOneWidget);

    // Nút giữa nằm giữa hai tab trái và hai tab phải, đúng giữa chiều ngang màn hình.
    final x = tester.getCenter(scan).dx;
    expect(tester.getCenter(find.text('Sổ thu chi')).dx, lessThan(x));
    expect(tester.getCenter(find.text('Kế hoạch')).dx, greaterThan(x));
    expect(x, closeTo(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, 1));
  });

  testWidgets('nút giữa có nhãn trợ năng, vùng chạm tối thiểu 48 và mở màn quét', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_router()));

    expect(find.bySemanticsLabel('Quét mã QR chuyển khoản'), findsOneWidget);
    final box = tester.getSize(find.ancestor(of: find.byIcon(LucideIcons.scanQrCode), matching: find.byType(InkWell)).first);
    expect(box.width, greaterThanOrEqualTo(48));
    expect(box.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byIcon(LucideIcons.scanQrCode));
    await tester.pumpAndSettle();

    expect(find.text('QUET QR'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('chạm một tab mở đúng màn', (tester) async {
    await tester.pumpWidget(_app(_router()));

    await tester.tap(find.text('Kế hoạch'));
    await tester.pumpAndSettle();

    expect(find.text('KE HOACH'), findsOneWidget);
  });

  testWidgets('chạm tab đang đứng thì không điều hướng lại', (tester) async {
    await tester.pumpWidget(_app(_router()));

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });
}
