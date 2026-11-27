import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/widgets/cash_flow_card.dart';

Map<String, dynamic> _json({Map<String, dynamic>? cashFlow}) => {
      'totalSpentCents': 1000000,
      'totalIncomeCents': 3000000,
      'netCents': 2000000,
      'prevMonthSpentCents': 0,
      'transactionCount': 3,
      'cashFlow': cashFlow,
    };

void main() {
  test('monthly-summary đọc cashFlow; không có thì null', () {
    final s = MonthlySummary.fromJson(_json(cashFlow: {
      'netCents': -3000000,
      'loanOutflowCents': 5000000,
      'loanInflowCents': 0,
      'groupFundOutflowCents': 0,
      'groupFundInflowCents': 0,
      'transferOutflowCents': 0,
      'transferInflowCents': 0,
      'refundSurplusCents': 0,
      'reversalNetCents': 0,
    }));

    expect(s.cashFlow!.netCents, BigInt.from(-3000000));
    expect(s.cashFlow!.otherParts, [('Cho vay / trả nợ', BigInt.from(-5000000))]);
    expect(MonthlySummary.fromJson(_json()).cashFlow, isNull);
  });

  testWidgets('thẻ hiện số dư thay đổi âm và bấm thì giải thích phần vay nợ', (tester) async {
    final flow = CashFlow.fromJson({'netCents': -3000000, 'loanOutflowCents': 5000000});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CashFlowCard(cashFlow: flow, incomeCents: BigInt.from(3000000), spentCents: BigInt.from(1000000))),
    ));

    expect(find.textContaining('-3.000.000'), findsOneWidget);
    expect(find.textContaining('Thu nhập'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cash-flow-card')));
    await tester.pump();

    expect(find.text('Cho vay / trả nợ'), findsOneWidget);
    expect(find.textContaining('-5.000.000'), findsOneWidget);
  });
}
