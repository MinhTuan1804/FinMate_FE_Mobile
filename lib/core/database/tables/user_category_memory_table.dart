import 'package:drift/drift.dart';

/// Ghi nhớ danh mục riêng của người dùng, chỉ nằm trên máy: món (và cửa hàng nếu có) người dùng đã xác nhận thuộc danh mục nào.
/// Khóa là dạng đã bỏ dấu, chữ thường (xem `memoryKey` ở phía gọi); [merchantKey] rỗng khi không có cửa hàng.
class UserCategoryMemory extends Table {
  TextColumn get merchantKey => text().withDefault(const Constant(''))();
  TextColumn get itemKey => text()();
  TextColumn get categorySlug => text()();

  /// Số lần người dùng xác nhận đúng danh mục này liên tiếp; đổi sang danh mục khác thì đếm lại từ 1
  IntColumn get confirmCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {merchantKey, itemKey};
}
