import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/transactions/presentation/widgets/failed_sync_banner.dart';

Future<void> insert(AppDatabase db, String id, String syncStatus) => db.insertLocalTransaction(LocalTransactionsCompanion.insert(
      id: id,
      clientRequestId: 'req-$id',
      amountCents: BigInt.from(1000),
      transactionType: 'Debit',
      status: 'Confirmed',
      financialAccountId: 'acc',
      transactedAt: DateTime(2026, 10, 13),
      syncStatus: Value(syncStatus),
    ));

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('failedSyncCount chỉ đếm các giao dịch server đã từ chối (failed), không đếm pending hay synced', () async {
    await insert(db, 'a', 'failed');
    await insert(db, 'b', 'failed');
    await insert(db, 'c', 'pending');
    await insert(db, 'd', 'synced');

    expect(await db.failedSyncCount(), 2);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: FailedSyncBanner())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không có giao dịch bị từ chối thì không hiện gì', (tester) async {
    await tester.runAsync(() => insert(db, 'a', 'pending'));
    await pump(tester);

    expect(find.textContaining('chưa đồng bộ được'), findsNothing);
  });

  testWidgets('có giao dịch bị server từ chối: báo số lượng và nói rõ chúng vẫn nằm trên máy', (tester) async {
    await tester.runAsync(() async {
      await insert(db, 'a', 'failed');
      await insert(db, 'b', 'failed');
    });
    await pump(tester);

    expect(find.textContaining('2 giao dịch chưa đồng bộ được'), findsOneWidget);
    expect(find.textContaining('vẫn nằm trên máy'), findsOneWidget);
  });
}
