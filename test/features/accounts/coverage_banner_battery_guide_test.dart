import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';
import 'package:finmate/features/accounts/presentation/screens/battery_guide_screen.dart';
import 'package:finmate/features/accounts/presentation/widgets/data_coverage_banner.dart';

DataCoverage _coverage(String level, {String? manufacturer}) => DataCoverage.fromJson({
      'windowDays': 30,
      'coveragePercent': 40,
      'level': level,
      'accounts': [],
      'devices': [
        {'installationId': 'i1', 'status': 'ok', 'permissionGranted': true, 'listenerConnected': true, 'manufacturer': manufacturer},
      ],
    });

void main() {
  testWidgets('độ phủ thấp: thẻ có nút hướng dẫn, mở trang pin với hãng máy đã báo', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, _) => Scaffold(body: dataCoverageBanner(c, _coverage('poor', manufacturer: 'Xiaomi'))!)),
      GoRoute(path: '/battery-guide', builder: (_, s) => BatteryGuideScreen(manufacturer: s.extra as String?)),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chỉ 40%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coverage-battery-guide')));
    await tester.pumpAndSettle();

    expect(find.text('Xiaomi / Redmi / POCO (máy của bạn)'), findsOneWidget);
    expect(find.textContaining('Tự khởi động'), findsOneWidget); // phần của máy mình mở sẵn
  });

  testWidgets('độ phủ tốt: không có nút hướng dẫn pin', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: dataCoverageBanner(c, _coverage('good'))!))));

    expect(find.byKey(const ValueKey('coverage-battery-guide')), findsNothing);
  });
}
