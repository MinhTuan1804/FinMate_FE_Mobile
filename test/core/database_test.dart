import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Core Database - Local Transactions & Offline Sync Test', () {
    test('Chèn và truy vấn giao dịch cục bộ thành công', () async {
      final now = DateTime.now();
      await db.insertLocalTransaction(LocalTransactionsCompanion.insert(
        id: 'tx-123',
        clientRequestId: 'req-uuid-456',
        amountCents: BigInt.from(50000),
        transactionType: 'Debit',
        status: 'Draft',
        financialAccountId: 'acc-wallet-1',
        transactedAt: now,
      ));

      final all = await db.getAllTransactions();
      expect(all.length, 1);
      expect(all.first.id, 'tx-123');
      expect(all.first.amountCents, BigInt.from(50000));
      expect(all.first.status, 'Draft');
      expect(all.first.clientRequestId, 'req-uuid-456');
    });

    test('clearAll xóa giao dịch cục bộ và hàng đợi; pendingSyncCount đếm hàng đợi', () async {
      await db.insertLocalTransaction(LocalTransactionsCompanion.insert(
        id: 'tx-1',
        clientRequestId: 'req-1',
        amountCents: BigInt.from(1000),
        transactionType: 'Debit',
        status: 'Confirmed',
        financialAccountId: 'acc-1',
        transactedAt: DateTime.now(),
      ));
      await db.enqueueSync(SyncQueueCompanion.insert(
        clientRequestId: 'req-1',
        endpoint: '/api/v1/transactions',
        payload: '{}',
        createdAt: DateTime.now(),
      ));
      expect(await db.pendingSyncCount(), 1);

      await db.clearAll();

      expect(await db.getAllTransactions(), isEmpty);
      expect(await db.getPendingSyncItems(), isEmpty);
      expect(await db.pendingSyncCount(), 0);
    });

    test('Hàng đợi SyncQueue enqueue và lấy danh sách FIFO', () async {
      await db.enqueueSync(SyncQueueCompanion.insert(
        clientRequestId: 'uuid-1',
        endpoint: '/api/v1/transactions',
        payload: '{"amountCents": 30000}',
        createdAt: DateTime.now(),
      ));

      await db.enqueueSync(SyncQueueCompanion.insert(
        clientRequestId: 'uuid-2',
        endpoint: '/api/v1/transactions',
        payload: '{"amountCents": 60000}',
        createdAt: DateTime.now().add(const Duration(seconds: 1)),
      ));

      final pending = await db.getPendingSyncItems();
      expect(pending.length, 2);
      expect(pending.first.clientRequestId, 'uuid-1');
      expect(pending.last.clientRequestId, 'uuid-2');

      // Đánh dấu hoàn thành xóa khỏi queue
      await db.removeSyncItem(pending.first.id);
      final remaining = await db.getPendingSyncItems();
      expect(remaining.length, 1);
      expect(remaining.first.clientRequestId, 'uuid-2');
    });
  });

  group('Database cục bộ theo từng người dùng', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('finmate_db_test'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<void> insertRow(AppDatabase d, String id) => d.insertLocalTransaction(LocalTransactionsCompanion.insert(
          id: id,
          clientRequestId: 'req-$id',
          amountCents: BigInt.from(1000),
          transactionType: 'Debit',
          status: 'Confirmed',
          financialAccountId: 'acc',
          transactedAt: DateTime(2026, 10, 13),
        ));

    test('logout_keeps_unsynced_rows_for_that_user: mở lại database của cùng người dùng vẫn thấy dữ liệu', () async {
      final first = AppDatabase.forUser('user-a', directory: dir);
      await insertRow(first, 'tx-1');
      await first.close();

      final again = AppDatabase.forUser('user-a', directory: dir);
      addTearDown(again.close);

      expect((await again.getAllTransactions()).map((t) => t.id), ['tx-1']);
    });

    test('other_user_never_sees_rows: mỗi người dùng một tệp riêng', () async {
      final a = AppDatabase.forUser('user-a', directory: dir);
      await insertRow(a, 'tx-a');
      await a.close();

      final b = AppDatabase.forUser('user-b', directory: dir);
      addTearDown(b.close);

      expect(await b.getAllTransactions(), isEmpty);
    });

    test('legacy_with_unsynced_is_quarantined_not_adopted: không giao dữ liệu chưa gửi của một người cho người khác', () async {
      final legacy = File('${dir.path}/finmate_local.sqlite');
      final old = AppDatabase.forTesting(NativeDatabase(legacy));
      await insertRow(old, 'tx-old');
      await old.enqueueSync(SyncQueueCompanion.insert(clientRequestId: 'req-tx-old', endpoint: '/e', payload: '{}', createdAt: DateTime(2026, 10, 13)));
      await old.close();

      final b = AppDatabase.forUser('user-b', directory: dir);
      addTearDown(b.close);

      expect(await b.getAllTransactions(), isEmpty);
      expect(await b.pendingSyncCount(), 0);
      expect(await legacy.exists(), isFalse);
      expect(File('${dir.path}/finmate_local_legacy_unsynced.sqlite').existsSync(), isTrue); // giữ nguyên để không mất hẳn
    });

    test('legacy_cache_only_is_removed: chỉ là bộ đệm đọc từ server thì xóa, không giao cho ai', () async {
      final legacy = File('${dir.path}/finmate_local.sqlite');
      final old = AppDatabase.forTesting(NativeDatabase(legacy));
      await insertRow(old, 'tx-cached');
      await old.close();

      final b = AppDatabase.forUser('user-b', directory: dir);
      addTearDown(b.close);

      expect(await b.getAllTransactions(), isEmpty);
      expect(await legacy.exists(), isFalse);
      expect(File('${dir.path}/finmate_local_legacy_unsynced.sqlite').existsSync(), isFalse);
    });

    test('account_deletion_removes_file', () async {
      final a = AppDatabase.forUser('user-a', directory: dir);
      await insertRow(a, 'tx-1');
      await a.close();
      expect(File('${dir.path}/finmate_local_user-a.sqlite').existsSync(), isTrue);

      await AppDatabase.deleteUserFiles('user-a', directory: dir);

      expect(File('${dir.path}/finmate_local_user-a.sqlite').existsSync(), isFalse);
    });

    test('migration_v1_to_v2_keeps_transactions: nâng cấp thêm bảng bộ nhớ và giữ giao dịch', () async {
      final file = File('${dir.path}/finmate_local_user-a.sqlite');
      final v2 = AppDatabase.forUser('user-a', directory: dir);
      await insertRow(v2, 'tx-1');
      await v2.customStatement('DROP TABLE user_category_memory');
      await v2.customStatement('PRAGMA user_version = 1');
      await v2.close();
      expect(file.existsSync(), isTrue);

      final upgraded = AppDatabase.forUser('user-a', directory: dir);
      addTearDown(upgraded.close);

      expect((await upgraded.getAllTransactions()).map((t) => t.id), ['tx-1']);
      await upgraded.insertPending(PendingMessagesCompanion.insert(id: 'p1', kind: 'text', content: 'ăn phở 45k', source: 'chat', createdAt: DateTime(2026, 10, 13))); // bảng hàng chờ (v3) cũng được tạo
      expect((await upgraded.allPending()).single.id, 'p1');
      await upgraded.rememberCategory(itemKey: 'ca phe', categorySlug: 'food');
      expect((await upgraded.categoryMemory('', 'ca phe'))!.categorySlug, 'food');
    });
  });

  group('Bộ nhớ danh mục riêng của người dùng', () {
    test('memory_upsert_increments_confirm_count: xác nhận cùng danh mục thì tăng số lần', () async {
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');

      final row = await db.categoryMemory('', 'ca phe hat');

      expect((row!.categorySlug, row.confirmCount), ('shopping', 2));
    });

    test('đổi sang danh mục khác thì lựa chọn mới nhất thắng và đếm lại từ 1', () async {
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'shopping');
      await db.rememberCategory(itemKey: 'ca phe hat', categorySlug: 'food');

      final row = await db.categoryMemory('', 'ca phe hat');

      expect((row!.categorySlug, row.confirmCount), ('food', 1));
    });

    test('cùng món nhưng khác cửa hàng là hai ghi nhớ riêng', () async {
      await db.rememberCategory(merchantKey: 'highlands', itemKey: 'ca phe', categorySlug: 'food');
      await db.rememberCategory(merchantKey: 'bach hoa xanh', itemKey: 'ca phe', categorySlug: 'shopping');

      expect((await db.categoryMemory('highlands', 'ca phe'))!.categorySlug, 'food');
      expect((await db.categoryMemory('bach hoa xanh', 'ca phe'))!.categorySlug, 'shopping');
      expect(await db.categoryMemory('', 'ca phe'), isNull);
    });
  });
}
