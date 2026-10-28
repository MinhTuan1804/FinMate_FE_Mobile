import 'package:drift/drift.dart' as drift;
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Entity -> dòng SQLite. Backend không trả clientRequestId nên dùng id làm giá trị duy nhất thay thế.
LocalTransactionsCompanion toCompanion(TransactionEntity tx, {String? syncStatus}) {
  return LocalTransactionsCompanion(
    id: drift.Value(tx.id),
    clientRequestId: drift.Value(tx.clientRequestId ?? tx.id),
    amountCents: drift.Value(tx.amountCents),
    transactionType: drift.Value(tx.type.apiValue),
    status: drift.Value(tx.status == TransactionStatus.draft ? 'Draft' : 'Confirmed'),
    categoryId: drift.Value(tx.categoryId),
    financialAccountId: drift.Value(tx.accountId),
    counterAccountId: drift.Value(tx.toAccountId),
    merchantName: drift.Value(tx.merchantName),
    description: drift.Value(tx.description),
    transactedAt: drift.Value(tx.date),
    syncStatus: drift.Value(syncStatus ?? (tx.isSynced ? 'synced' : 'pending')),
  );
}

/// Dòng SQLite -> entity (tên danh mục không được lưu cục bộ)
TransactionEntity fromRow(LocalTransaction row) {
  return TransactionEntity(
    id: row.id,
    amountCents: row.amountCents,
    type: TransactionType.fromApi(row.transactionType),
    categoryId: row.categoryId,
    merchantName: row.merchantName,
    description: row.description ?? '',
    date: row.transactedAt,
    accountId: row.financialAccountId,
    toAccountId: row.counterAccountId,
    status: row.status == 'Draft' ? TransactionStatus.draft : TransactionStatus.confirmed,
    isSynced: row.syncStatus == 'synced',
    clientRequestId: row.clientRequestId,
  );
}
