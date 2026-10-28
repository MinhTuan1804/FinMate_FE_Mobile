import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/database/tables/transactions_table.dart';
import 'package:finmate/core/database/tables/pending_messages_table.dart';
import 'package:finmate/core/database/tables/sync_queue_table.dart';
import 'package:finmate/core/database/tables/user_category_memory_table.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

part 'app_database.g.dart';

/// Database của NGƯỜI DÙNG ĐANG ĐĂNG NHẬP (mỗi người một tệp). Đăng xuất không xóa gì: dữ liệu chưa đồng bộ nằm ở đây và phải sống sót.
/// Chưa đăng nhập thì chỉ là một database rỗng trong bộ nhớ.
final databaseProvider = Provider<AppDatabase>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final db = userId == null ? AppDatabase.forTesting(NativeDatabase.memory()) : AppDatabase.forUser(userId);
  ref.onDispose(db.close);
  return db;
});

@DriftDatabase(tables: [LocalTransactions, SyncQueue, UserCategoryMemory, PendingMessages])
class AppDatabase extends _$AppDatabase {
  /// Tệp riêng của một người dùng. Tệp dùng chung của bản cũ (`finmate_local.sqlite`) được gán cho người đăng nhập đầu tiên sau khi nâng cấp.
  AppDatabase.forUser(String userId, {Directory? directory}) : super(_openUserConnection(userId, directory));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(userCategoryMemory);
          if (from < 3) await m.createTable(pendingMessages);
        },
      );

  /// Xóa tệp database của một người dùng (khi người dùng xóa tài khoản)
  static Future<void> deleteUserFiles(String userId, {Directory? directory}) async {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('${p.join(dir.path, _fileName(userId))}$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  // Hàng chờ câu chat/giọng nói chưa phân tích được vì mất mạng
  Future<void> insertPending(PendingMessagesCompanion entry) => into(pendingMessages).insert(entry, mode: InsertMode.insertOrIgnore);

  Future<List<PendingMessage>> allPending() => (select(pendingMessages)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])).get();

  Future<int> deletePending(String id) => (delete(pendingMessages)..where((t) => t.id.equals(id))).go();

  // Bộ nhớ danh mục riêng
  Future<UserCategoryMemoryData?> categoryMemory(String merchantKey, String itemKey) =>
      (select(userCategoryMemory)..where((t) => t.merchantKey.equals(merchantKey) & t.itemKey.equals(itemKey))).getSingleOrNull();

  /// Người dùng xác nhận [itemKey] thuộc [categorySlug]: cùng danh mục thì tăng số lần, khác thì lựa chọn mới nhất thắng và đếm lại từ 1
  Future<void> rememberCategory({String merchantKey = '', required String itemKey, required String categorySlug, DateTime? now}) async {
    final existing = await categoryMemory(merchantKey, itemKey);
    final count = existing != null && existing.categorySlug == categorySlug ? existing.confirmCount + 1 : 1;
    await into(userCategoryMemory).insert(
      UserCategoryMemoryCompanion.insert(
        merchantKey: Value(merchantKey),
        itemKey: itemKey,
        categorySlug: categorySlug,
        confirmCount: Value(count),
        updatedAt: now ?? DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // Transactions Queries
  Future<List<LocalTransaction>> getAllTransactions() => select(localTransactions).get();

  Future<List<LocalTransaction>> getTransactionsByStatus(String status) =>
      (select(localTransactions)..where((tbl) => tbl.status.equals(status))).get();

  Future<int> insertLocalTransaction(LocalTransactionsCompanion entry) =>
      into(localTransactions).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteTransactionByClientRequestId(String clientRequestId) =>
      (delete(localTransactions)..where((t) => t.clientRequestId.equals(clientRequestId))).go();

  /// Đánh dấu giao dịch không thể đồng bộ (server từ chối quá số lần cho phép)
  Future<int> markSyncFailed(String clientRequestId) =>
      (update(localTransactions)..where((t) => t.clientRequestId.equals(clientRequestId)))
          .write(const LocalTransactionsCompanion(syncStatus: Value('failed')));

  Future<bool> updateTransactionStatus(String id, String status, String syncStatus) async {
    final count = await (update(localTransactions)..where((t) => t.id.equals(id))).write(
      LocalTransactionsCompanion(
        status: Value(status),
        syncStatus: Value(syncStatus),
      ),
    );
    return count > 0;
  }

  // SyncQueue Queries (FIFO)
  Future<int> enqueueSync(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<SyncQueueData>> getPendingSyncItems() =>
      (select(syncQueue)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])).get();

  Future<int> pendingSyncCount() async => (await select(syncQueue).get()).length;

  /// Giao dịch ở máy mà server đã từ chối nhiều lần (xem [markSyncFailed]); chúng được giữ lại chứ không xóa
  Future<int> failedSyncCount() async => (await (select(localTransactions)..where((t) => t.syncStatus.equals('failed'))).get()).length;

  /// Xóa toàn bộ dữ liệu cục bộ (khi đăng xuất/hết phiên) để không lộ dữ liệu cho người dùng sau
  Future<void> clearAll() async {
    await delete(localTransactions).go();
    await delete(syncQueue).go();
    await delete(userCategoryMemory).go();
    await delete(pendingMessages).go();
  }

  Future<int> removeSyncItem(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<int> incrementRetryCount(int id, int currentCount) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(retryCount: Value(currentCount + 1)),
      );
}

/// Tệp dùng chung của bản cũ không thuộc về ai nên KHÔNG giao cho người đăng nhập đầu tiên: giao nhầm thì giao dịch chưa gửi của người này
/// bị gửi bằng ví của người kia và bị server từ chối. Nếu còn giao dịch chưa gửi thì giữ nguyên ở một tệp riêng (không code nào đọc),
/// ngược lại nó chỉ là bộ đệm đọc từ server nên xóa.
Future<void> _retireLegacyFile(Directory dir) async {
  final legacy = File(p.join(dir.path, 'finmate_local.sqlite'));
  if (!await legacy.exists()) return;
  var hasUnsynced = false;
  try {
    final old = AppDatabase.forTesting(NativeDatabase(legacy));
    hasUnsynced = await old.pendingSyncCount() > 0;
    await old.close();
  } catch (_) {
    hasUnsynced = true; // không đọc được thì giữ lại, đừng xóa
  }
  final quarantine = File(p.join(dir.path, 'finmate_local_legacy_unsynced.sqlite'));
  if (hasUnsynced && !await quarantine.exists()) {
    await legacy.rename(quarantine.path);
  } else if (!hasUnsynced) {
    await legacy.delete();
  }
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    final extra = File('${legacy.path}$suffix');
    if (await extra.exists()) await extra.delete();
  }
}

String _fileName(String userId) => 'finmate_local_$userId.sqlite';

LazyDatabase _openUserConnection(String userId, Directory? directory) {
  return LazyDatabase(() async {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, _fileName(userId)));
    await _retireLegacyFile(dir);
    return NativeDatabase.createInBackground(file);
  });
}
