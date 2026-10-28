import 'dart:convert';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/transactions/data/local_transaction_mapper.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Dịch vụ đồng bộ hàng đợi ghi ngoại tuyến lên Backend
class SyncService {
  /// Số lần server được phép từ chối trước khi giao dịch bị đánh dấu "failed"
  static const maxRetries = 5;

  final AppDatabase db;
  final ApiClient apiClient;

  SyncService({required this.db, required this.apiClient});

  /// Gửi tuần tự (FIFO) các bản ghi trong SyncQueue. Trả về số bản ghi đã đồng bộ.
  /// - Mất mạng: dừng ngay, không tính là thất bại.
  /// - Server từ chối: tăng retryCount; đủ [maxRetries] thì đánh dấu failed và bỏ qua từ đó.
  Future<int> processQueue() async {
    final items = await db.getPendingSyncItems();
    var syncedCount = 0;

    for (final item in items) {
      if (item.retryCount >= maxRetries) continue;

      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;
        final response = await apiClient.post(item.endpoint, data: payload, fromJsonT: (json) => json);

        await db.removeSyncItem(item.id);
        await db.deleteTransactionByClientRequestId(item.clientRequestId);
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final server = TransactionEntity.fromJson(data).copyWith(isSynced: true);
          await db.insertLocalTransaction(toCompanion(server));
        }
        syncedCount++;
      } on NetworkException {
        break;
      } catch (_) {
        await db.incrementRetryCount(item.id, item.retryCount);
        if (item.retryCount + 1 >= maxRetries) {
          await db.markSyncFailed(item.clientRequestId);
        }
      }
    }

    return syncedCount;
  }
}
