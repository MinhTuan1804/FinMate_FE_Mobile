import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/widgets/transactions_filter_sheet.dart';

Future<void> _open(
  WidgetTester tester,
  void Function(TransactionFilterResult?) onResult, {
  TransactionFilterResult initial = const TransactionFilterResult(),
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                onResult(await TransactionsFilterSheet.show(context, initial)),
            child: const Text('mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('360dp: không tràn ngang, chọn loại + Áp dụng trả đúng kết quả', (
    tester,
  ) async {
    TransactionFilterResult? result;
    await _open(tester, (r) => result = r);
    expect(tester.takeException(), isNull);
    expect(find.text('Bộ lọc giao dịch'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filter-type-expense')));
    await tester.pump();
    await tester.tap(find.text('Năm trước'));
    await tester.pump();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();

    final y = DateTime.now().year - 1;
    expect(result!.type, TransactionType.expense);
    expect(result!.draftsOnly, isFalse);
    expect(result!.range, DateTimeRange(start: DateTime(y), end: DateTime(y, 12, 31)));
  });

  testWidgets('Đặt lại xóa mọi lựa chọn; Chờ duyệt bật chế độ nháp', (
    tester,
  ) async {
    TransactionFilterResult? result;
    await _open(
      tester,
      (r) => result = r,
      initial: const TransactionFilterResult(type: TransactionType.income),
    );
    await tester.tap(find.byKey(const ValueKey('filter-status-draft')));
    await tester.pump();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(result!.draftsOnly, isTrue);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt lại'));
    await tester.pump();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(result!.type, isNull);
    expect(result!.draftsOnly, isFalse);
    expect(result!.range, isNull);
  });
}
