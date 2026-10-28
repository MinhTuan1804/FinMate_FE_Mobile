import 'package:drift/drift.dart';

/// Bảng hàng đợi đồng bộ ngoại tuyến (FIFO Sync Queue)
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientRequestId => text().unique()();
  TextColumn get endpoint => text()();
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}
