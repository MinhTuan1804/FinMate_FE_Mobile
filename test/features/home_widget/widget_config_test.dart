import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/home_widget/domain/widget_config.dart';

void main() {
  group('HomeWidgetKind', () {
    test('id khớp 3 kích thước và fromId đọc ngược lại đúng', () {
      expect(HomeWidgetKind.values.map((k) => k.id), ['w1', 'w2', 'w4x4']);
      for (final k in HomeWidgetKind.values) {
        expect(HomeWidgetKind.fromId(k.id), k);
      }
    });

    test('fromId với id lạ/rỗng rơi về Tổng quan (W2)', () {
      expect(HomeWidgetKind.fromId('w9'), HomeWidgetKind.overview);
      expect(HomeWidgetKind.fromId(''), HomeWidgetKind.overview);
    });
  });

  group('WidgetConfig', () {
    test('mặc định: bật gợi ý AI, mọi tài khoản, làm mới ngay + định kỳ', () {
      const c = WidgetConfig();
      expect(c.aiSuggestionsEnabled, isTrue);
      expect(c.sourceAccountId, isNull);
      expect(c.refreshMode, WidgetRefreshMode.immediateAndPeriodic);
    });

    test('copyWith chỉ đổi trường được nêu', () {
      final c = const WidgetConfig().copyWith(aiSuggestionsEnabled: false, refreshMode: WidgetRefreshMode.batterySaver);
      expect(c.aiSuggestionsEnabled, isFalse);
      expect(c.refreshMode, WidgetRefreshMode.batterySaver);
      expect(c.sourceAccountId, isNull);
    });

    test('copyWith(sourceAccountId: () => null) đưa về "Tất cả tài khoản"; không truyền thì giữ nguyên', () {
      final picked = const WidgetConfig().copyWith(sourceAccountId: () => 'acc-1');
      expect(picked.sourceAccountId, 'acc-1');
      expect(picked.copyWith(aiSuggestionsEnabled: false).sourceAccountId, 'acc-1');
      expect(picked.copyWith(sourceAccountId: () => null).sourceAccountId, isNull);
    });

    test('refreshMode.name là khoá lưu xuống SharedPreferences và đọc lại được', () {
      for (final m in WidgetRefreshMode.values) {
        expect(WidgetRefreshMode.values.firstWhere((x) => x.name == m.name), m);
      }
      expect(WidgetRefreshMode.values.map((m) => m.name), ['immediateAndPeriodic', 'batterySaver']);
    });
  });
}
