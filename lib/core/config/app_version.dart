/// Phiên bản của app này, khớp `version:` trong pubspec.yaml (một test giữ hai nơi này không lệch nhau). Hằng số thay vì đọc lúc chạy vì dự án
/// chưa cài `package_info_plus` và quy tắc dự án cấm thêm dependency khi chưa hỏi.
const String kAppVersion = '1.0.0';

/// `true` nếu [current] cũ hơn [other] (so từng số theo thứ tự: 1.10.0 mới hơn 1.9.0). Phiên bản không đọc được thì coi là KHÔNG cũ hơn:
/// một cấu hình sai ở server không được khóa mọi người ngoài app.
bool isOlderVersion(String current, String other) {
  final a = _parts(current);
  final b = _parts(other);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}

List<int>? _parts(String version) {
  final pieces = version.trim().split('.');
  if (pieces.length != 3) return null;
  final numbers = pieces.map(int.tryParse).toList();
  return numbers.contains(null) ? null : numbers.cast<int>();
}
