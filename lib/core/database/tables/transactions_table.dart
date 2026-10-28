import 'package:drift/drift.dart';

/// Bảng lưu trữ giao dịch cục bộ (Local Offline Database)
class LocalTransactions extends Table {
  TextColumn get id => text()(); // UUID từ server hoặc client
  TextColumn get clientRequestId => text().unique()(); // UUID chống trùng lặp (Idempotent)
  Int64Column get amountCents => int64()(); // BIGINT đơn vị đồng VND (quy tắc không dùng float)
  TextColumn get transactionType => text()(); // Debit, Credit, Transfer
  TextColumn get status => text()(); // Draft, Confirmed, Pending
  TextColumn get categoryId => text().nullable()();
  TextColumn get financialAccountId => text()();
  TextColumn get counterAccountId => text().nullable()(); // Cho giao dịch chuyển nội bộ
  TextColumn get merchantName => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get transactedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))(); // pending, synced

  @override
  Set<Column> get primaryKey => {id};
}
