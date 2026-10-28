import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../../fixtures/fixture.dart';

/// Ghi cả nhóm giao dịch của một câu nhiều khoản: ở máy, một lần (được tất cả hoặc không gì), rồi đồng bộ sau.
class _FlakyDb extends AppDatabase {
  int enqueues = 0;
  final int failOn;
  _FlakyDb(this.failOn) : super.forTesting(NativeDatabase.memory());

  @override
  Future<int> enqueueSync(SyncQueueCompanion entry) {
    if (++enqueues == failOn) throw StateError('ghi đĩa lỗi');
    return super.enqueueSync(entry);
  }
}

NewTransaction item(String id, int cents) => NewTransaction(
      accountId: 'acc-1',
      categoryId: 'cat-1',
      amountCents: BigInt.from(cents),
      type: TransactionType.expense,
      description: 'món $id',
      date: DateTime(2026, 10, 13, 12),
      source: 'Manual',
      clientRequestId: id,
    );

void main() {
  test('ghi mọi dòng và mọi mục hàng đợi ở máy, không gọi mạng', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final adapter = RouteAdapter((o) => throw StateError('không được gọi mạng khi ghi ở máy'));
    final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

    final saved = await repo.createTransactionsLocally([item('r1', 40000), item('r2', 70000)]);

    expect(saved.map((t) => (t.clientRequestId, t.amountCents, t.isSynced)), [('r1', BigInt.from(40000), false), ('r2', BigInt.from(70000), false)]);
    expect((await db.getAllTransactions()).map((r) => r.clientRequestId), unorderedEquals(['r1', 'r2']));
    expect((await db.getPendingSyncItems()).map((q) => q.clientRequestId), ['r1', 'r2']);
    expect(adapter.requests, isEmpty);
  });

  test('ghi lỗi giữa chừng: không dòng nào và không mục hàng đợi nào còn lại (được tất cả hoặc không gì)', () async {
    final db = _FlakyDb(2);
    addTearDown(db.close);
    final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);

    await expectLater(repo.createTransactionsLocally([item('r1', 40000), item('r2', 70000), item('r3', 1000)]), throwsA(isA<StateError>()));

    expect(await db.getAllTransactions(), isEmpty);
    expect(await db.pendingSyncCount(), 0);
  });

  test('đồng bộ sau: mỗi khoản được gửi đúng một lần với mã của nó, rồi hàng đợi trống', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);
    await repo.createTransactionsLocally([item('r1', 40000), item('r2', 70000)]);
    final server = (fixtureData('transactions') as List)[2];
    final online = RouteAdapter((o) => respondJson({'success': true, 'data': server}));
    final sync = SyncService(db: db, apiClient: testApiClient(online));

    expect(await sync.processQueue(), 2);
    expect(await sync.processQueue(), 0);

    expect(online.requests.map((r) => (r.data as Map)['clientRequestId']), ['r1', 'r2']);
    expect(await db.pendingSyncCount(), 0);
  });

  test('server từ chối khi đồng bộ: bản ghi ở máy được GIỮ và đánh dấu chưa đồng bộ được, không bị xóa', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);
    await repo.createTransactionsLocally([item('r1', 40000)]);
    final rejecting = SyncService(
      db: db,
      apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': false, 'data': null, 'error': {'code': 'VALIDATION_ERROR', 'message': 'sai'}}, status: 422))),
    );

    for (var i = 0; i < SyncService.maxRetries; i++) {
      await rejecting.processQueue();
    }

    final rows = await db.getAllTransactions();
    expect(rows.single.clientRequestId, 'r1');
    expect(rows.single.syncStatus, 'failed');
  });
}
