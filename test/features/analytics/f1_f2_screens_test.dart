import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/f2_category_report_screen.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';

final _now = DateTime.now();

MonthlySummary _summary() => MonthlySummary(
      totalSpentCents: BigInt.from(18250000),
      totalIncomeCents: BigInt.from(32400000),
      netCents: BigInt.from(14150000),
      prevMonthSpentCents: BigInt.from(19050000),
      transactionCount: 12,
      changePercent: -4.2,
    );

CategoryBreakdown _breakdown() => CategoryBreakdown(totalSpentCents: BigInt.from(18250000), items: [
      CategoryShare(categoryId: 'c1', name: 'Ăn uống & Tiệc tùng', slug: 'food', spentCents: BigInt.from(6800000), percent: 37.3),
      CategoryShare(categoryId: 'c2', name: 'Nhà cửa & Tiện ích', slug: 'housing', spentCents: BigInt.from(4500000), percent: 24.7),
    ]);

List<TimelineDaySummary> _days() => [
      TimelineDaySummary(date: DateTime(_now.year, _now.month, 1), totalSpentCents: BigInt.from(2450000), totalIncomeCents: BigInt.zero, transactionCount: 2),
      TimelineDaySummary(date: DateTime(_now.year, _now.month, 2), totalSpentCents: BigInt.from(500000), totalIncomeCents: BigInt.zero, transactionCount: 1),
    ];

final _budgets = [
  BudgetForecastEntity(
    budgetId: 'b1',
    categoryId: 'c1',
    limitCents: BigInt.from(6600000),
    spentCents: BigInt.from(6800000),
    projectedCents: BigInt.from(7000000),
    projectedPercent: 106,
    status: 'over',
    maxDailySpendCents: BigInt.zero,
    daysRemaining: 10,
    basis: 'pace',
  ),
];

Future<void> _pump(WidgetTester tester, Widget screen, double width, {List<TimelineDaySummary>? days, bool dark = false}) async {
  GlassColors.dark = dark;
  addTearDown(() => GlassColors.dark = false);
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      monthlySummaryProvider.overrideWith((ref) async => _summary()),
      monthlySummaryForMonthProvider.overrideWith((ref, ym) async => _summary()),
      categoryBreakdownProvider.overrideWith((ref) async => _breakdown()),
      categoryBreakdownByTypeForMonthProvider.overrideWith((ref, ymt) async => _breakdown()),
      forecastProvider.overrideWith((ref) async => Forecast.empty),
      spendingInsightsProvider.overrideWith((ref) async => const []),
      dailySpendingProvider.overrideWith((ref, range) async => days ?? _days()),
      budgetForecastProvider.overrideWith((ref) async => _budgets),
    ],
    child: MaterialApp(theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light), builder: (context, child) => MediaQuery(
        // Test không có phông thật nên chữ rơi về Ahem (rộng 1em/ký tự, gấp ~1,7 lần Be Vietnam Pro/Inter); thu 0,6 để bề rộng gần thực tế.
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)),
        child: child!,
      ),
      home: screen),
  ));
  await tester.pumpAndSettle();
}

/// Mọi màu chữ đang dựng, để bắt màu của chế độ kia bị giữ lại (const/biến toàn cục).
Set<Color> _textColors(WidgetTester tester) {
  final colors = <Color>{};
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    rt.text.visitChildren((span) {
      final c = span.style?.color;
      if (c != null) colors.add(c);
      return true;
    });
  }
  return colors;
}

void _noException(WidgetTester tester) {
  final e = tester.takeException();
  expect(e, isNull, reason: e is FlutterError ? e.toStringDeep() : '$e');
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('F1 không tràn ở ${width.toInt()}dp, có biểu đồ cột và tooltip VNĐ khi chạm', (tester) async {
      await _pump(tester, const AnalyticsScreen(), width);
      _noException(tester);
      expect(find.byType(BarChart), findsOneWidget);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final item = chart.data.barTouchData.touchTooltipData.getTooltipItem(chart.data.barGroups.first, 0, chart.data.barGroups.first.barRods.first, 0);
      expect(item!.text, '2.450.000 ₫ • 1 Th${_now.month}');
    });

    testWidgets('F2 không tràn ở ${width.toInt()}dp, nút PDF khóa kèm "Sắp có"', (tester) async {
      await _pump(tester, const F2CategoryReportScreen(), width);
      _noException(tester);
      expect(find.text('TỔNG CHI'), findsOneWidget);
      expect(find.textContaining('Vượt ngân sách 200.000 ₫'), findsOneWidget);
      expect(find.text('37,3%'), findsOneWidget);
      expect(find.textContaining('(-800.000 ₫)'), findsOneWidget, reason: 'chênh lệch so với tháng trước');
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Sắp có'), findsOneWidget);
    });
  }

  testWidgets('F1 không có chi tiêu trong kỳ: trạng thái rỗng, không vẽ cột giả', (tester) async {
    await _pump(tester, const AnalyticsScreen(), 390, days: const []);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Chưa có chi tiêu trong kỳ này.'), findsOneWidget);
  });

  test('token: chữ trên nền ink đủ tương phản AA ở cả hai chế độ', () {
    for (final dark in [false, true]) {
      GlassColors.dark = dark;
      expect(_contrast(GlassColors.onInk, GlassColors.ink), greaterThanOrEqualTo(4.5), reason: 'dark=$dark');
    }
    GlassColors.dark = false;
  });

  for (final entry in {'F1': const AnalyticsScreen(), 'F2': const F2CategoryReportScreen()}.entries) {
    testWidgets('${entry.key} chế độ tối: không giữ màu chữ của chế độ sáng và không tràn', (tester) async {
      GlassColors.dark = false;
      final light = {GlassColors.textPrimary, GlassColors.textSecondary, GlassColors.textMuted};
      GlassColors.dark = true;
      await _pump(tester, entry.value, 360, dark: true);

      _noException(tester);
      final used = _textColors(tester);
      expect(used.intersection(light), isEmpty, reason: 'còn màu chữ sáng trong chế độ tối');
      expect(used.where((c) => c == Colors.white), isEmpty, reason: 'chữ trắng cứng');
    });
  }
}
