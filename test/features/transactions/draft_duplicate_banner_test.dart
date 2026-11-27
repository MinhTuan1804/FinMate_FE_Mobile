import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_links.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_transaction_tile.dart';

TransactionEntity _draft({TransactionLinks links = TransactionLinks.none}) => TransactionEntity(
      id: 'd1',
      amountCents: BigInt.from(45000),
      type: TransactionType.expense,
      description: 'Highlands',
      date: DateTime(2026, 11, 20, 9),
      accountId: 'a1',
      status: TransactionStatus.draft,
      links: links,
    );

Future<List<Object?>> _pump(WidgetTester tester, TransactionEntity draft) async {
  final opened = <Object?>[];
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: DraftTransactionTile(draft: draft, busy: false, onConfirm: () {}, onEdit: () {}))),
    GoRoute(path: '/transaction-detail', builder: (_, s) {
      opened.add(s.extra);
      return const Scaffold(body: Text('detail'));
    }),
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('nháp nghi trùng hiện khoản bị trùng và nút Xem mở chi tiết để Gộp / Không trùng', (tester) async {
    final draft = _draft(
      links: TransactionLinks.fromJson({
        'duplicateStatus': 'Suspected',
        'duplicateOf': {'id': 't9', 'amountCents': 45000, 'transactedAt': '2026-11-20T02:00:00Z', 'source': 'Manual', 'merchantName': 'Highlands Coffee'},
      }),
    );
    final opened = await _pump(tester, draft);

    expect(find.textContaining('Có thể trùng với Highlands Coffee'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draft-duplicate-review-d1')));
    await tester.pumpAndSettle();

    expect(opened.single, same(draft));
  });

  testWidgets('nháp không nghi trùng hoặc đã bấm "không trùng" thì không có dải cảnh báo', (tester) async {
    await _pump(tester, _draft());
    expect(find.byKey(const ValueKey('draft-duplicate-d1')), findsNothing);

    await _pump(
      tester,
      _draft(links: TransactionLinks.fromJson({
        'duplicateStatus': 'Dismissed',
        'duplicateOf': {'id': 't9', 'amountCents': 45000, 'source': 'Manual'},
      })),
    );
    expect(find.byKey(const ValueKey('draft-duplicate-d1')), findsNothing);
  });
}
