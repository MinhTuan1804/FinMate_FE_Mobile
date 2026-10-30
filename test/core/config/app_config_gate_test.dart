import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/config/app_config_gate.dart';
import 'package:finmate/core/config/brand_logo.dart';
import 'package:finmate/core/theme/app_theme.dart';

class _FakeController extends AppConfigController {
  _FakeController(this.initial, {this.onRefresh});

  final AppConfig initial;
  final Future<void> Function(_FakeController controller)? onRefresh;

  @override
  AppConfig build() => initial;

  void set(AppConfig config) => state = config;

  @override
  Future<void> refresh() async => await onRefresh?.call(this);
}

AppConfig _maintenance({DateTime? end}) => AppConfig(maintenance: MaintenanceConfig(enabled: true, title: 'Đang bảo trì', message: 'Quay lại sau 10 phút', estimatedEndAt: end));

AppConfig _version({String min = '1.0.0', String latest = '1.0.0', bool force = false, String url = ''}) =>
    AppConfig(appVersion: AppVersionConfig(minVersion: min, latestVersion: latest, forceUpdate: force, storeUrl: url));

Future<void> _pump(WidgetTester tester, _FakeController controller, {String version = '1.0.0'}) => tester.pumpWidget(ProviderScope(
      key: UniqueKey(),  // mỗi lần dựng một phạm vi mới: Riverpod giữ trạng thái khi chỉ đổi overrides
      overrides: [appConfigProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: AppConfigGate(
          currentVersion: version,
          child: Scaffold(body: Center(child: ElevatedButton(onPressed: () {}, child: const Text('Nội dung app')))),
        ),
      ),
    ));

void main() {
  testWidgets('không bảo trì và app đủ mới: chỉ thấy nội dung app', (tester) async {
    await _pump(tester, _FakeController(const AppConfig()));

    expect(find.text('Nội dung app'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Cần cập nhật FinMate'), findsNothing);
  });

  testWidgets('đang bảo trì: popup hiện, app bên dưới không nhận chạm và không vào cây trợ năng', (tester) async {
    var taps = 0;
    final controller = _FakeController(_maintenance());
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),  // mỗi lần dựng một phạm vi mới: Riverpod giữ trạng thái khi chỉ đổi overrides
      overrides: [appConfigProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: AppConfigGate(child: Scaffold(body: Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('Nội dung app'))))),
      ),
    ));

    expect(find.text('Đang bảo trì'), findsOneWidget);
    expect(find.text('Quay lại sau 10 phút'), findsOneWidget);
    await tester.tap(find.text('Nội dung app'), warnIfMissed: false);
    expect(taps, 0);
    expect(tester.getSemantics(find.text('Thử lại')).label, 'Thử lại');
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));  // vùng chạm tối thiểu
  });

  testWidgets('nút Thử lại có trạng thái đang kiểm tra rồi báo hệ thống vẫn bảo trì', (tester) async {
    final release = Completer<void>();
    final controller = _FakeController(_maintenance(), onRefresh: (_) => release.future);
    await _pump(tester, controller);

    await tester.tap(find.text('Thử lại'));
    await tester.pump();

    expect(find.text('Đang kiểm tra...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);  // không bấm chồng

    release.complete();
    await tester.pump();

    expect(find.text('Hệ thống vẫn đang bảo trì. Vui lòng thử lại sau.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('hết bảo trì thì popup biến mất và app chạm được lại', (tester) async {
    var taps = 0;
    final controller = _FakeController(_maintenance(), onRefresh: (c) async => c.set(const AppConfig(version: 2)));
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),  // mỗi lần dựng một phạm vi mới: Riverpod giữ trạng thái khi chỉ đổi overrides
      overrides: [appConfigProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: AppConfigGate(child: Scaffold(body: Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('Nội dung app'))))),
      ),
    ));

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Đang bảo trì'), findsNothing);
    await tester.tap(find.text('Nội dung app'));
    expect(taps, 1);
  });

  testWidgets('giờ dự kiến xong chỉ hiện khi còn ở tương lai', (tester) async {
    await _pump(tester, _FakeController(_maintenance(end: DateTime.now().add(const Duration(hours: 1)))));
    expect(find.textContaining('Dự kiến xong lúc'), findsOneWidget);

    await _pump(tester, _FakeController(_maintenance(end: DateTime.now().subtract(const Duration(hours: 1)))));
    expect(find.textContaining('Dự kiến xong lúc'), findsNothing);
  });

  testWidgets('app dưới phiên bản tối thiểu bị buộc cập nhật', (tester) async {
    await _pump(tester, _FakeController(_version(min: '2.0.0', latest: '2.1.0', url: 'https://example.com/app')), version: '1.0.0');

    expect(find.text('Cần cập nhật FinMate'), findsOneWidget);
    expect(find.textContaining('2.1.0'), findsOneWidget);
    expect(find.text('https://example.com/app'), findsOneWidget);
  });

  testWidgets('bản mới hơn nhưng không bắt buộc thì không chặn; bật Buộc cập nhật thì chặn', (tester) async {
    await _pump(tester, _FakeController(_version(latest: '1.5.0')));
    expect(find.text('Cần cập nhật FinMate'), findsNothing);

    await _pump(tester, _FakeController(_version(latest: '1.5.0', force: true)));
    expect(find.text('Cần cập nhật FinMate'), findsOneWidget);
  });

  testWidgets('bảo trì được ưu tiên hơn cập nhật', (tester) async {
    final both = AppConfig(
      maintenance: const MaintenanceConfig(enabled: true, title: 'Đang bảo trì'),
      appVersion: const AppVersionConfig(minVersion: '9.0.0'),
    );
    await _pump(tester, _FakeController(both));

    expect(find.text('Đang bảo trì'), findsOneWidget);
    expect(find.text('Cần cập nhật FinMate'), findsNothing);
  });

  testWidgets('sao chép liên kết cửa hàng: ghi vào clipboard và báo đã sao chép rồi trở lại', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester, _FakeController(_version(min: '2.0.0', url: 'https://example.com/app')));

    await tester.tap(find.text('Sao chép liên kết'));
    await tester.pump();

    expect(copied, 'https://example.com/app');
    expect(find.text('Đã sao chép'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sao chép liên kết'), findsOneWidget);
  });

  testWidgets('không có liên kết cửa hàng thì chỉ nhắc mở cửa hàng', (tester) async {
    await _pump(tester, _FakeController(_version(min: '2.0.0')));

    expect(find.textContaining('mở cửa hàng ứng dụng'), findsOneWidget);
    expect(find.text('Sao chép liên kết'), findsNothing);
  });

  testWidgets('BrandLogo: mặc định là dấu hiệu của app, có logo https thì dựng ảnh', (tester) async {
    Future<void> pumpLogo(AppConfig config) => tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [appConfigProvider.overrideWith(() => _FakeController(config))],
          child: MaterialApp(theme: AppTheme.darkTheme, home: const Scaffold(body: Center(child: BrandLogo()))),
        ));

    await pumpLogo(const AppConfig());
    expect(find.byType(Image), findsNothing);

    await pumpLogo(const AppConfig(theme: ThemeConfig(logoUrl: 'https://cdn.example.com/logo.png')));
    expect(find.byType(Image), findsOneWidget);
  });
}
