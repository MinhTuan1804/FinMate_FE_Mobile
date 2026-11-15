import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/features/profile/presentation/screens/appearance_settings_screen.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppearanceSettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('chọn Tối rồi Hệ thống đổi themeModeProvider ngay', (tester) async {
    await pump(tester);
    expect(container.read(themeModeProvider), ThemeMode.system); // mặc định theo hệ thống

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('theme-system')));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  testWidgets('công tắc giảm hiệu ứng trong suốt đổi reduceTransparencyProvider; không còn công tắc ẩn số dư giả', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('reduce-transparency')));
    await tester.pumpAndSettle();
    expect(container.read(reduceTransparencyProvider), isTrue);
    // 3 công tắc chưa có cơ chế (ẩn số dư, giảm chuyển động, tăng tương phản) hiện khóa kèm "Sắp có", không bật được.
    expect(find.text('Sắp có'), findsNWidgets(3));
    final locked = tester.widgetList<Switch>(find.byType(Switch)).where((s) => s.onChanged == null);
    expect(locked, hasLength(3));
  });

  testWidgets('kéo thanh cỡ chữ đổi textScaleProvider; mặc định là Chuẩn 1.0', (tester) async {
    await pump(tester);
    expect(container.read(textScaleProvider), 1.0);

    await tester.drag(find.byKey(const ValueKey('text-scale')), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(container.read(textScaleProvider), 1.15);

    await tester.drag(find.byKey(const ValueKey('text-scale')), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(container.read(textScaleProvider), 0.9);
  });

  testWidgets('ở 320dp không tràn bố cục', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
