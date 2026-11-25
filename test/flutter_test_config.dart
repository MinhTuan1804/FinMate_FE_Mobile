import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kênh native của 3 widget màn hình chính (W1/W2/4×4, xem `core/native/widget_refresh_bridge.dart`)
/// được `await` ngay trong luồng lưu giao dịch/tài khoản/kế hoạch (`accounts_controller.dart`,
/// `transactions/data_refresh.dart`, `planning_controller.dart`) kể từ khi gộp nhánh Luồng 9
/// (2026-11-18). Không mock thì `invokeMethod` không ai trả lời trong `flutter test`, treo mãi và
/// làm `pumpAndSettle` timeout ở bất kỳ test nào đi qua các luồng đó — phát hiện 12 test lỗi sau khi
/// gộp nhánh `dev/tuan`. Đặt `null` ở đây một lần cho toàn bộ test suite, giống cách từng file test
/// khác (vd `native_token_storage_test.dart`) đã làm riêng cho kênh của nó, để mọi test không cần
/// tự biết/tự mock kênh này.
const _widgetRefreshChannel = MethodChannel('com.finmate.app/widget_refresh');

/// Kênh của gói `home_widget` (đọc/ghi `pendingRoute` trong `NotificationCaptureScope.
/// _consumePendingRoute`, xem `notification_capture_scope.dart`). Cùng lý do với kênh ở trên: không
/// mock thì `getWidgetData`/`saveWidgetData` không ai trả lời trong `flutter test`, treo mãi.
const _homeWidgetChannel = MethodChannel('home_widget');

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // Một handler THẬT trả lời ngay (không phải `null` — `null` nghĩa là "chưa mock gì", đúng cái
  // đang gây treo, nên không có tác dụng gì).
  messenger.setMockMethodCallHandler(_widgetRefreshChannel, (call) async => null);
  messenger.setMockMethodCallHandler(_homeWidgetChannel, (call) async => null);
  await testMain();
}
