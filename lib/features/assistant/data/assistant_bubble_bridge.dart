import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cách hiện bong bóng: [system] = Bubbles API của Android; [overlay] = FinMate tự vẽ đè (MIUI/HyperOS, Android < 11).
enum AssistantBubbleMode { system, overlay }

/// Trạng thái bong bóng FinMate AI phía Android (xem bubble/AssistantBubble.kt).
typedef AssistantBubbleStatus = ({
  bool supported,
  AssistantBubbleMode mode,
  bool notificationPermission,
  bool bubblesAllowed,
  bool overlayPermission,
  bool showing,
});

/// Cầu nối tới bong bóng FinMate AI kiểu Messenger (Bubbles API, Android 11+).
/// Nền tảng không có kênh (iOS, test) coi như không hỗ trợ thay vì ném lỗi.
class AssistantBubbleBridge {
  AssistantBubbleBridge([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('com.example.finmate/assistant_bubble');

  final MethodChannel _channel;

  static const unsupported = (
    supported: false,
    mode: AssistantBubbleMode.system,
    notificationPermission: false,
    bubblesAllowed: false,
    overlayPermission: false,
    showing: false,
  );

  Future<AssistantBubbleStatus> status() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('status');
      if (map == null) return unsupported;
      bool flag(String key) => map[key] == true;
      return (
        supported: flag('supported'),
        mode: map['mode'] == 'overlay' ? AssistantBubbleMode.overlay : AssistantBubbleMode.system,
        notificationPermission: flag('notificationPermission'),
        bubblesAllowed: flag('bubblesAllowed'),
        overlayPermission: flag('overlayPermission'),
        showing: flag('showing'),
      );
    } on MissingPluginException {
      return unsupported;
    }
  }

  Future<bool> requestNotificationPermission() async => await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;

  /// Đăng bong bóng; false nếu thiếu quyền thông báo.
  Future<bool> show() async => await _channel.invokeMethod<bool>('show') ?? false;

  Future<void> hide() => _channel.invokeMethod<void>('hide');

  Future<void> openBubbleSettings() => _channel.invokeMethod<void>('openBubbleSettings');

  /// Màn "Hiện trên các ứng dụng khác" của FinMate (chế độ overlay).
  Future<void> openOverlaySettings() => _channel.invokeMethod<void>('openOverlaySettings');

  /// Thu khung chat vẽ đè (chạm vùng trống phía trên khung).
  Future<void> closePanel() => _channel.invokeMethod<void>('closePanel');

  /// Từ khung chat mini mở app FinMate đầy đủ.
  Future<void> openFullApp() => _channel.invokeMethod<void>('openFullApp');
}

final assistantBubbleBridgeProvider = Provider<AssistantBubbleBridge>((ref) => AssistantBubbleBridge());

/// true khi đang chạy trong cửa sổ nổi của bong bóng (entrypoint assistantBubbleMain).
final isAssistantBubbleProvider = Provider<bool>((ref) => false);

/// true khi là khung chat của bong bóng TỰ VẼ ĐÈ (entrypoint assistantOverlayMain): Flutter phải tự vẽ khung
/// kiểu Messenger. Bong bóng hệ thống (Bubbles API) thì Android đã vẽ khung sẵn nên để false.
final isAssistantOverlayProvider = Provider<bool>((ref) => false);
