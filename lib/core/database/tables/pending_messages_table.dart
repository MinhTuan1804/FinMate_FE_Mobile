import 'package:drift/drift.dart';

/// Câu chat hoặc giọng nói chưa phân tích được vì mất mạng: giữ ở máy để tự phân tích khi có mạng lại
class PendingMessages extends Table {
  /// Cũng là mã chống trùng gửi cho server, dùng lại ở mỗi lần thử nên server không ghi hai lần
  TextColumn get id => text()();
  TextColumn get kind => text()(); // text | voice
  TextColumn get content => text()(); // câu chữ, hoặc đường dẫn tệp ghi âm đã sao chép
  TextColumn get source => text()(); // chat | voice | receipt
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
