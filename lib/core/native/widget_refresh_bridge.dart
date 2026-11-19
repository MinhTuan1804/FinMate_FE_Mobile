import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.finmate/widget_refresh');

/// Báo native đồng bộ + vẽ lại ngay cả 3 widget home-screen (W1/W2/4×4) — gọi sau mọi thay đổi dữ
/// liệu mà chúng hiển thị (tài khoản, ngân sách/mục tiêu, giao dịch), thay vì chờ chu kỳ định kỳ
/// 30 phút/2 giờ. Không có kênh (iOS, test) -> bỏ qua an toàn.
///
/// debugPrint TẠM THỜI (gỡ sau khi xác nhận lỗi "widget không tự cập nhật" đã hết) — để xem trong
/// `flutter logs`/logcat liệu lệnh này có THẬT SỰ được gọi mỗi lần tài khoản/ngân sách tải lại hay
/// không, tách biệt với lỗi phía native.
Future<void> syncAllWidgets() async {
  try {
    debugPrint('[WidgetSync] syncAllWidgets() invoking native channel');
    await _channel.invokeMethod<void>('syncAllWidgets');
    debugPrint('[WidgetSync] syncAllWidgets() native call returned');
  } on MissingPluginException {
    // Không chạy trên Android — bỏ qua an toàn, cùng cách WidgetConfigBridge đang làm.
  } catch (e) {
    debugPrint('[WidgetSync] syncAllWidgets() FAILED: $e');
  }
}
