import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/transactions/data/local_transaction_mapper.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_page.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    apiClient: ref.watch(apiClientProvider),
    database: ref.watch(databaseProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(db: ref.watch(databaseProvider), apiClient: ref.watch(apiClientProvider));
});

/// Một giao dịch mới để ghi theo nhóm (xem [TransactionRepository.createTransactionsLocally])
class NewTransaction {
  final String accountId;
  final String? categoryId;
  final BigInt amountCents;
  final TransactionType type;
  final String? merchantName;
  final String description;
  final DateTime date;
  final String source;
  final String clientRequestId;

  const NewTransaction({
    required this.accountId,
    this.categoryId,
    required this.amountCents,
    required this.type,
    this.merchantName,
    this.description = '',
    required this.date,
    this.source = 'Manual',
    required this.clientRequestId,
  });
}

class TransactionRepository {
  final ApiClient apiClient;
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  static const _transactionsPath = '/api/v1/transactions';
  static const _transferPath = '/api/v1/transactions/transfer';

  TransactionRepository({required this.apiClient, required this.database});

  /// Lấy một trang giao dịch từ server (cache lại vào SQLite).
  /// Chỉ khi MẤT MẠNG mới trả dữ liệu cache; mọi lỗi khác (401, 4xx, 5xx) được ném lại.
  /// [status] mặc định là đã xác nhận vì BE trả MỌI trạng thái khi thiếu tham số; nháp không bao giờ được cache.
  Future<TransactionPage> getTransactions({
    TransactionType? type,
    DateTime? fromDate,
    DateTime? toDate,
    String? cursor,
    int limit = 20,
    TransactionStatus status = TransactionStatus.confirmed,
  }) async {
    try {
      final response = await apiClient.get(
        _transactionsPath,
        queryParameters: {
          if (type != null) 'type': type.apiValue,
          'status': status == TransactionStatus.draft ? 'Draft' : 'Confirmed',
          if (fromDate != null) 'fromDate': fromDate.toUtc().toIso8601String(),
          if (toDate != null) 'toDate': toDate.toUtc().toIso8601String(),
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
        },
        fromJsonT: (json) => (json as List).map((e) => TransactionEntity.fromJson(e as Map<String, dynamic>)).toList(),
      );

      final items = response.data ?? const <TransactionEntity>[];
      for (final tx in items.where((t) => t.status != TransactionStatus.draft)) {
        await database.insertLocalTransaction(toCompanion(tx.copyWith(isSynced: true)));
      }
      return TransactionPage(items: items, nextCursor: response.meta?.nextCursor);
    } on NetworkException {
      // Nháp chỉ có trên server nên offline không có gì để hiện.
      if (status == TransactionStatus.draft) return const TransactionPage(items: []);
      return TransactionPage(items: await _cached(type: type, fromDate: fromDate, toDate: toDate));
    }
  }

  Future<List<TransactionEntity>> _cached({TransactionType? type, DateTime? fromDate, DateTime? toDate}) async {
    final rows = await database.getAllTransactions();
    final list = rows
        .map(fromRow)
        .where((t) => t.status == TransactionStatus.confirmed)
        .where((t) => type == null || t.type == type)
        .where((t) => fromDate == null || !t.date.isBefore(fromDate))
        .where((t) => toDate == null || !t.date.isAfter(toDate))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Xác nhận một nháp (POST .../confirm). Cần mạng: không xếp hàng đồng bộ; lỗi (vd 409 khi không còn là nháp) được ném lại.
  Future<TransactionEntity> confirmDraft(String id, {String? categoryId}) async {
    final response = await apiClient.post(
      '$_transactionsPath/$id/confirm',
      data: {if (categoryId != null) 'categoryId': categoryId},
      fromJsonT: (json) => TransactionEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Sửa nháp (PATCH, gửi đủ body). Nháp chỉ ở server nên không ghi cache local.
  Future<TransactionEntity> updateDraft({
    required String id,
    required String accountId,
    String? categoryId,
    required BigInt amountCents,
    required TransactionType type,
    required DateTime date,
    String? merchantName,
    String description = '',
  }) async {
    final response = await apiClient.patch(
      '$_transactionsPath/$id',
      data: {
        'financialAccountId': accountId,
        'counterAccountId': null,
        'categoryId': categoryId,
        'amountCents': amountCents.toInt(),
        'transactionType': type.apiValue,
        'transactedAt': date.toUtc().toIso8601String(),
        'merchantName': merchantName,
        'description': description,
      },
      fromJsonT: (json) => TransactionEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Tạo giao dịch (offline-first): ghi local trước rồi gửi server kèm clientRequestId.
  /// Mất mạng -> xếp hàng đồng bộ; server từ chối -> xóa bản local và ném lỗi.
  /// [clientRequestId] chỉ truyền khi gửi lại cùng một giao dịch (thử lại nhóm hóa đơn lỗi), để BE không tạo trùng.
  Future<TransactionEntity> createTransaction({
    required String accountId,
    String? categoryId,
    required BigInt amountCents,
    required TransactionType type,
    String? merchantName,
    String description = '',
    required DateTime date,
    String source = 'Manual',
    String? receiptScanId,
    String? receiptGroup,
    String? clientRequestId,
  }) {
    clientRequestId ??= _uuid.v4();
    return _submit(
      TransactionEntity(
        id: 'local-$clientRequestId',
        amountCents: amountCents,
        type: type,
        categoryId: categoryId,
        merchantName: merchantName,
        description: description,
        date: date,
        accountId: accountId,
        isSynced: false,
        clientRequestId: clientRequestId,
        source: source,
        receiptScanId: receiptScanId,
        receiptGroup: receiptGroup,
      ),
      _transactionsPath,
    );
  }

  /// Ghi cả nhóm giao dịch (một câu nhiều khoản) ở MÁY trong một lần: được tất cả hoặc không gì. Mỗi khoản có một mục hàng đợi đồng bộ với
  /// mã chống trùng của nó. Không gọi mạng: gửi lên server là việc của đồng bộ (`SyncService.processQueue`), mất mạng hay không đều xong ngay.
  /// Server từ chối khi đồng bộ thì bản ghi ở máy được giữ và đánh dấu `failed`, không bị xóa.
  Future<List<TransactionEntity>> createTransactionsLocally(List<NewTransaction> items) {
    return database.transaction(() async {
      final saved = <TransactionEntity>[];
      for (final item in items) {
        final entity = TransactionEntity(
          id: 'local-${item.clientRequestId}',
          amountCents: item.amountCents,
          type: item.type,
          categoryId: item.categoryId,
          merchantName: item.merchantName,
          description: item.description,
          date: item.date,
          accountId: item.accountId,
          isSynced: false,
          clientRequestId: item.clientRequestId,
          source: item.source,
        );
        await database.insertLocalTransaction(toCompanion(entity));
        await database.enqueueSync(
          SyncQueueCompanion(
            clientRequestId: drift.Value(item.clientRequestId),
            endpoint: drift.Value(_transactionsPath),
            payload: drift.Value(jsonEncode(entity.toRequestJson())),
            createdAt: drift.Value(DateTime.now()),
          ),
        );
        saved.add(entity);
      }
      return saved;
    });
  }

  /// Chuyển tiền nội bộ giữa 2 tài khoản (BR-26, BR-27)
  Future<TransactionEntity> transferInternal({
    required BigInt amountCents,
    required String fromAccountId,
    required String toAccountId,
    String description = '',
    required DateTime date,
  }) {
    final clientRequestId = _uuid.v4();
    return _submit(
      TransactionEntity.internalTransfer(
        id: 'local-$clientRequestId',
        amountCents: amountCents,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        description: description,
        date: date,
        isSynced: false,
        clientRequestId: clientRequestId,
      ),
      _transferPath,
    );
  }

  Future<TransactionEntity> _submit(TransactionEntity entity, String endpoint) async {
    final clientRequestId = entity.clientRequestId!;
    await database.insertLocalTransaction(toCompanion(entity));

    try {
      final response = await apiClient.post(
        endpoint,
        data: entity.toRequestJson(),
        fromJsonT: (json) => TransactionEntity.fromJson(json as Map<String, dynamic>),
      );
      final server = response.data!.copyWith(isSynced: true);
      await database.deleteTransactionByClientRequestId(clientRequestId);
      await database.insertLocalTransaction(toCompanion(server));
      return server;
    } on NetworkException {
      await database.enqueueSync(
        SyncQueueCompanion(
          clientRequestId: drift.Value(clientRequestId),
          endpoint: drift.Value(endpoint),
          payload: drift.Value(jsonEncode(entity.toRequestJson())),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
      return entity;
    } catch (_) {
      await database.deleteTransactionByClientRequestId(clientRequestId);
      rethrow;
    }
  }
}
