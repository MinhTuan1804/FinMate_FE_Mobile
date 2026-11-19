import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/analytics/presentation/screens/f6_ai_summary_screen.dart';

final _insights = [
  SpendingInsight(id: '1', insightType: 'unusual_spending', title: 'Chi ăn uống tăng mạnh', body: 'Bạn chi nhiều hơn thường lệ ở mục Ăn uống trong tuần này, hãy xem lại các khoản lớn.', categoryName: 'Ăn uống', amountCents: BigInt.from(6800000), isRead: false),
  SpendingInsight(id: '2', insightType: 'recurring_detected', title: 'Phát hiện khoản định kỳ', body: 'Một khoản thanh toán lặp lại hằng tháng.', categoryName: null, amountCents: null, isRead: true),
];

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      monthlySummaryProvider.overrideWith((ref) async => MonthlySummary(
            totalSpentCents: BigInt.from(21500000),
            totalIncomeCents: BigInt.from(35000000),
            netCents: BigInt.from(13500000),
            prevMonthSpentCents: BigInt.zero,
            transactionCount: 3,
            changePercent: null,
          )),
      spendingInsightsProvider.overrideWith((ref) async => _insights),
    ],
    child: const MaterialApp(home: F6AiSummaryScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 360.0]) {
    testWidgets('F6 không tràn ở ${width.toInt()}dp, ẩn điểm sức khỏe, có "Sắp có"', (tester) async {
      await _pump(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.text('Chi ăn uống tăng mạnh'), findsOneWidget);
      expect(find.text('Đánh dấu đã xem'), findsOneWidget); // chỉ thẻ chưa đọc
      expect(find.textContaining('/100'), findsNothing);
      expect(find.textContaining('Sắp có'), findsOneWidget);
    });
  }

  testWidgets('F6 chế độ tối không tràn', (tester) async {
    GlassColors.dark = true;
    addTearDown(() => GlassColors.dark = false);
    await _pump(tester, 360);
    expect(tester.takeException(), isNull);
  });
}
