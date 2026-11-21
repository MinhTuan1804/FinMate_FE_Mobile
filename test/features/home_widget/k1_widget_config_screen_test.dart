import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/home_widget/data/widget_config_bridge.dart';
import 'package:finmate/features/home_widget/domain/widget_config.dart';
import 'package:finmate/features/home_widget/presentation/screens/k1_widget_config_screen.dart';
import '../../fixtures/fixture.dart';

/// Bridge giả: không đụng MethodChannel/SharedPreferences, chỉ ghi lại lời gọi.
class FakeBridge extends WidgetConfigBridge {
  FakeBridge({this.widgetId = 7, this.kind = HomeWidgetKind.overview, this.pinned = const [], this.stored = const WidgetConfig()});

  final int? widgetId;
  final HomeWidgetKind kind;
  final List<int> pinned;
  final WidgetConfig stored;
  final saved = <({List<int> ids, HomeWidgetKind kind, WidgetConfig config})>[];
  final finished = <bool>[];

  @override
  Future<int?> getWidgetId() async => widgetId;
  @override
  Future<HomeWidgetKind> getWidgetKind() async => kind;
  @override
  Future<List<int>> getPinnedWidgetIds(HomeWidgetKind kind) async => pinned;
  @override
  Future<WidgetConfig> loadConfig(int widgetId) async => stored;
  @override
  Future<void> saveConfig(List<int> widgetIds, HomeWidgetKind kind, WidgetConfig config) async =>
      saved.add((ids: widgetIds, kind: kind, config: config));
  @override
  Future<void> finishConfig({required bool accepted}) async => finished.add(accepted);
}

ResponseBody Function(RequestOptions) _routes({String spendable = 'finance_spendable', bool emptyAccounts = false}) => (o) {
      if (o.path.contains('/me/spendable')) return respondFixture(spendable);
      if (o.path.contains('/forecast/cashflow')) return respondFixture('cashflow');
      if (o.path.endsWith('/financial-accounts')) {
        return emptyAccounts ? respondJson({'success': true, 'data': [], 'error': null, 'meta': null}) : respondFixture('accounts');
      }
      return respondJson({'success': true, 'data': null, 'error': null, 'meta': null});
    };

Future<void> _pump(
  WidgetTester tester, {
  FakeBridge? bridge,
  double width = 390,
  bool dark = false,
  bool editAllPinned = false,
  HomeWidgetKind? initialKind,
  ResponseBody Function(RequestOptions)? routes,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  GlassColors.dark = dark;
  addTearDown(() => GlassColors.dark = false);
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApiClient(RouteAdapter(routes ?? _routes()))),
      ...overrides,
    ],
    child: MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: K1WidgetConfigScreen(bridge: bridge ?? FakeBridge(), editAllPinned: editAllPinned, initialKind: initialKind),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  testWidgets('chọn kích thước 2×2 / 4×2 / 4×4 đổi phần xem trước', (tester) async {
    await _pump(tester);
    expect(find.text('Cỡ 4×2'), findsOneWidget);
    expect(find.text('SỐ DƯ KHẢ DỤNG'), findsOneWidget);

    await tester.tap(find.text('2 × 2'));
    await tester.pumpAndSettle();
    expect(find.text('Cỡ 2×2'), findsOneWidget);
    expect(find.text('Hôm nay có thể chi tiêu an toàn'), findsOneWidget);
    expect(find.text('SỐ DƯ KHẢ DỤNG'), findsNothing);

    await tester.tap(find.text('4 × 4'));
    await tester.pumpAndSettle();
    expect(find.text('Cỡ 4×4'), findsOneWidget);
    expect(find.text('DỰ BÁO CUỐI THÁNG'), findsOneWidget);
    // dự báo cuối tháng lấy từ fixture cashflow (3.200.000), không phải số cứng
    expect(find.text(formatVnd(BigInt.from(3200000))), findsOneWidget);
  });

  testWidgets('xem trước dùng số liệu thật (không còn số cứng) và theo nguồn tiền đã chọn', (tester) async {
    await _pump(tester);
    expect(find.text(formatVnd(BigInt.from(34955000))), findsOneWidget); // 30.955.000 + 4.000.000
    expect(find.text('FinMate • Tất cả tài khoản'), findsOneWidget);
    expect(find.textContaining('42.850.000'), findsNothing);
    expect(find.textContaining('FinMate AI: Bạn đã tiêu'), findsNothing);
    expect(find.text('Đã chi tháng này: ${formatVnd(BigInt.from(8000000))}'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget); // 8.000.000 / 20.000.000

    await tester.tap(find.text('Vietcombank'));
    await tester.pumpAndSettle();
    expect(find.text('FinMate • Vietcombank'), findsOneWidget);
    expect(find.text(formatVnd(BigInt.from(30955000))), findsOneWidget);
  });

  testWidgets('tắt gợi ý thông minh ẩn vòng % trong xem trước', (tester) async {
    await _pump(tester);
    expect(find.text('40%'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('40%'), findsNothing);
    // widget thật không có chế độ ẩn số dư, nên số dư vẫn hiện
    expect(find.text(formatVnd(BigInt.from(34955000))), findsOneWidget);
  });

  testWidgets('Hoàn tất gọi bridge đúng id, loại và cấu hình đã chọn', (tester) async {
    final bridge = FakeBridge(widgetId: 7, kind: HomeWidgetKind.detail);
    await _pump(tester, bridge: bridge);
    expect(find.text('Cỡ 4×4'), findsOneWidget); // loại do native báo

    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Vietcombank'));
    await tester.tap(find.text('TIẾT KIỆM PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();

    expect(bridge.saved, hasLength(1));
    final s = bridge.saved.single;
    expect(s.ids, [7]);
    expect(s.kind, HomeWidgetKind.detail);
    expect(s.config.aiSuggestionsEnabled, isFalse);
    expect(s.config.sourceAccountId, '78b154c6-c8d8-4b6d-9367-981772ce5382');
    expect(s.config.refreshMode, WidgetRefreshMode.batterySaver);
    expect(bridge.finished, [true]);
  });

  testWidgets('nút đóng (X) báo huỷ và không lưu', (tester) async {
    final bridge = FakeBridge();
    await _pump(tester, bridge: bridge);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(bridge.saved, isEmpty);
    expect(bridge.finished, [false]);
  });

  testWidgets('editAllPinned: nạp cấu hình đã lưu và lưu cho mọi widget đang ghim', (tester) async {
    final bridge = FakeBridge(
      pinned: [3, 4],
      stored: const WidgetConfig(aiSuggestionsEnabled: false, refreshMode: WidgetRefreshMode.batterySaver),
    );
    await _pump(tester, bridge: bridge, editAllPinned: true, initialKind: HomeWidgetKind.safeSpend);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse); // lấy từ cấu hình đã lưu
    expect(find.text('DÙNG MẶC ĐỊNH'), findsOneWidget);
    expect(find.text('Cỡ 2×2'), findsOneWidget);

    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();
    expect(bridge.saved.single.ids, [3, 4]);
    expect(bridge.saved.single.kind, HomeWidgetKind.safeSpend);
    expect(bridge.saved.single.config.aiSuggestionsEnabled, isFalse);
  });

  testWidgets('xem trước: đang tải', (tester) async {
    await _pump(tester, settle: false, overrides: [
      spendableProvider.overrideWith((ref) => Completer<SpendableEntity>().future),
    ]);
    expect(find.text('Đang tải dữ liệu xem trước…'), findsOneWidget);
    expect(find.text('SỐ DƯ KHẢ DỤNG'), findsNothing);
    await tester.pump(const Duration(seconds: 1)); // để timer của client HTTP giả chạy xong
  });

  testWidgets('xem trước: lỗi có nút Thử lại và tải lại được', (tester) async {
    var fail = true;
    await _pump(tester, overrides: [
      spendableProvider.overrideWith((ref) async {
        if (fail) throw Exception('mất mạng');
        return SpendableEntity.fromJson(fixtureData('finance_spendable') as Map<String, dynamic>);
      }),
    ]);
    expect(find.text('Không tải được dữ liệu xem trước.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dữ liệu xem trước.'), findsNothing);
    expect(find.text('SỐ DƯ KHẢ DỤNG'), findsOneWidget);
  });

  testWidgets('xem trước: chưa có tài khoản/ngân sách -> khung trống có nhãn, không số giả', (tester) async {
    await _pump(tester, routes: _routes(spendable: 'finance_spendable_no_income', emptyAccounts: true));
    expect(find.textContaining('Chưa có tài khoản'), findsOneWidget);
    expect(find.text('Chưa đặt ngân sách tháng'), findsOneWidget);
    expect(find.textContaining('₫'), findsNothing);

    await tester.tap(find.text('2 × 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có dữ liệu'), findsOneWidget);
    expect(find.textContaining('₫'), findsNothing);
  });

  for (final width in [360.0, 320.0]) {
    for (final dark in [false, true]) {
      testWidgets('không tràn ở ${width.toInt()}dp ${dark ? 'chế độ tối' : 'chế độ sáng'} (cả 3 kích thước)', (tester) async {
        await _pump(tester, width: width, dark: dark);
        for (final k in ['2 × 2', '4 × 2', '4 × 4']) {
          await tester.tap(find.text(k));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tràn ở $k, ${width}dp');
        }
      });
    }
  }

  testWidgets('không có chữ trắng cứng: ở chế độ tối onInk là màu tối nên mọi Colors.white đều là màu cứng', (tester) async {
    await _pump(tester, dark: true);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.color, isNot(Colors.white), reason: '"${t.data}" dùng Colors.white cứng');
    }
  });

  for (final dark in [false, true]) {
    test('độ tương phản WCAG AA của cặp màu màn K1 (${dark ? 'tối' : 'sáng'})', () {
      GlassColors.dark = dark;
      addTearDown(() => GlassColors.dark = false);
      // Nền thật của thẻ = glassFill chồng lên canvas.
      final canvas = GlassColors.canvasMid;
      final panel = Color.alphaBlend(GlassColors.glassFill, canvas);
      expect(_contrast(GlassColors.textPrimary, panel), greaterThanOrEqualTo(4.5), reason: 'textPrimary/panel');
      expect(_contrast(GlassColors.textSecondary, panel), greaterThanOrEqualTo(4.5), reason: 'textSecondary/panel');
      expect(_contrast(GlassColors.onInk, GlassColors.ink), greaterThanOrEqualTo(4.5), reason: 'onInk/ink');
      expect(_contrast(GlassColors.textPrimary, canvas), greaterThanOrEqualTo(4.5), reason: 'textPrimary/canvas');
      expect(_contrast(GlassColors.textPrimary, GlassColors.secondarySurface), greaterThanOrEqualTo(4.5));
    });
  }
}
