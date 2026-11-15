import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_nav.dart';

void main() {
  // Máy Android phổ thông rộng 360dp; máy nhỏ hơn rộng 320dp. Thanh điều hướng không được tràn ngang ở cả hai.
  for (final width in [360.0, 320.0]) {
    testWidgets('GlassBottomNav không tràn ngang ở bề rộng ${width.toInt()}dp và đủ 5 mục', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selected = -2;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlassBottomNav(currentIndex: 0, onDestinationSelected: (i) => selected = i),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow trên thanh điều hướng dưới');
      for (final label in ['Trang chủ', 'Giao dịch', 'Quét QR', 'Kế hoạch', 'Phân tích']) {
        expect(find.text(label), findsOneWidget);
      }

      // Mọi mục nằm trọn trong màn hình
      for (final label in ['Trang chủ', 'Phân tích']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }

      await tester.tap(find.text('Phân tích'));
      expect(selected, 3);
    });
  }
}
