import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/features/transactions/data/local_transaction_mapper.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../fixtures/fixture.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final pending = TransactionEntity(
      id: 'local-req-1',
      amountCents: BigInt.from(45000),
      type: TransactionType.expense,
      description: 'Cơm trưa',
      date: DateTime.utc(2026, 9, 30),
      accountId: 'acc-1',
      isSynced: false,
      clientRequestId: 'req-1',
    );
    await db.insertLocalTransaction(toCompanion(pending));
    await db.enqueueSync(SyncQueueCompanion.insert(
      clientRequestId: 'req-1',
      endpoint: '/api/v1/transactions',
      payload: jsonEncode(pending.toRequestJson()),
      createdAt: DateTime.now(),
    ));
  });

  tearDown(() => db.close());

  SyncService serviceFor(RouteAdapter adapter) => SyncService(db: db, apiClient: testApiClient(adapter));

  test('thành công: gỡ khỏi hàng đợi và thay dòng local bằng dòng server đã đồng bộ', () async {
    final server = (fixtureData('transactions') as List)[2];
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': server}));

    final synced = await serviceFor(adapter).processQueue();

    expect(synced, 1);
    expect(await db.pendingSyncCount(), 0);
    final rows = await db.getAllTransactions();
    expect(rows.single.id, server['id']);
    expect(rows.single.syncStatus, 'synced');
    expect((adapter.requests.single.data as Map)['clientRequestId'], 'req-1');
  });

  test('mất mạng: dừng ngay, không tăng số lần thử', () async {
    final synced = await serviceFor(RouteAdapter((o) => throwNetworkDown(o))).processQueue();

    expect(synced, 0);
    final item = (await db.getPendingSyncItems()).single;
    expect(item.retryCount, 0);
    expect((await db.getAllTransactions()).single.syncStatus, 'pending');
  });

  test('server từ chối 5 lần: đánh dấu failed và không thử nữa', () async {
    final adapter = RouteAdapter((o) => respondJson({
          'success': false,
          'data': null,
          'error': {'code': 'BAD', 'message': 'Từ chối'},
        }, status: 400));
    final service = serviceFor(adapter);

    for (var i = 0; i < SyncService.maxRetries; i++) {
      await service.processQueue();
    }
    expect((await db.getPendingSyncItems()).single.retryCount, SyncService.maxRetries);
    expect((await db.getAllTransactions()).single.syncStatus, 'failed');

    final callsBefore = adapter.requests.length;
    await service.processQueue();
    expect(adapter.requests.length, callsBefore);
  });

  test('gửi theo thứ tự FIFO và gọi endpoint đã lưu (chuyển tiền)', () async {
    await db.enqueueSync(SyncQueueCompanion.insert(
      clientRequestId: 'req-2',
      endpoint: '/api/v1/transactions/transfer',
      payload: '{"amountCents":1}',
      createdAt: DateTime.now().add(const Duration(seconds: 1)),
    ));
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));

    await serviceFor(adapter).processQueue();

    expect(adapter.requests.map((r) => r.path), ['/api/v1/transactions', '/api/v1/transactions/transfer']);
  });
}
