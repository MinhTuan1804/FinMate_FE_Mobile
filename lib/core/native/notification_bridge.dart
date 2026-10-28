import 'package:flutter/services.dart';

enum NativeRefreshStatus { ok, expired, network }

class NativeRefreshResult {
  final NativeRefreshStatus status;
  final String? accessToken;
  const NativeRefreshResult(this.status, [this.accessToken]);
}

/// Cầu nối tới phía Android (owner duy nhất của token + hàng đợi thông báo).
/// Mọi phương thức nuốt MissingPluginException (iOS/test không có kênh) và trả mặc định an toàn.
class NotificationBridge {
  NotificationBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.example.finmate/notifications');

  final MethodChannel _channel;

  // Native xử lý trên thread pool nên các lệnh ghi không await nhau có thể bị đảo thứ tự;
  // xếp hàng ở đây để chúng tới native đúng thứ tự gọi.
  Future<void> _tail = Future<void>.value();

  Future<void> _serial(Future<void> Function() op) {
    final run = _tail.then((_) => op());
    _tail = run.then((_) {}, onError: (_) {}); // lỗi của một lệnh không làm gãy chuỗi
    return run;
  }

  Future<T> _safe<T>(Future<T> Function() op, T fallback) async {
    try {
      return await op();
    } on MissingPluginException {
      return fallback;
    }
  }

  Future<void> setSession({
    required String baseUrl,
    required String accessToken,
    required String refreshToken,
  }) =>
      _serial(() => _safe(
            () => _channel.invokeMethod<void>('setSession', {
              'baseUrl': baseUrl,
              'accessToken': accessToken,
              'refreshToken': refreshToken,
            }),
            null,
          ));

  Future<void> clearSession() =>
      _serial(() => _safe(() => _channel.invokeMethod<void>('clearSession'), null));

  Future<void> setMonitoredPackages(List<String> packages) => _serial(() => _safe(
        () => _channel.invokeMethod<void>('setMonitoredPackages', {'packages': packages}),
        null,
      ));

  Future<String?> getAccessToken() =>
      _safe(() => _channel.invokeMethod<String>('getAccessToken'), null);

  Future<String?> getRefreshToken() =>
      _safe(() => _channel.invokeMethod<String>('getRefreshToken'), null);

  /// Không có kênh -> `network` (lỗi tạm): interceptor không đăng xuất người dùng oan.
  Future<NativeRefreshResult> refreshSession({String? staleAccessToken}) => _safe(() async {
        final m = await _channel.invokeMapMethod<String, dynamic>(
          'refreshSession',
          {'staleAccessToken': staleAccessToken},
        );
        switch (m?['status']) {
          case 'ok':
            return NativeRefreshResult(NativeRefreshStatus.ok, m!['accessToken'] as String?);
          case 'expired':
            return const NativeRefreshResult(NativeRefreshStatus.expired);
          default:
            return const NativeRefreshResult(NativeRefreshStatus.network);
        }
      }, const NativeRefreshResult(NativeRefreshStatus.network));

  Future<bool> isNotificationAccessEnabled() => _safe(
        () async => await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ?? false,
        false,
      );

  Future<void> openNotificationAccessSettings() =>
      _safe(() => _channel.invokeMethod<void>('openNotificationAccessSettings'), null);

  Future<void> flushQueue() => _safe(() => _channel.invokeMethod<void>('flushQueue'), null);

  Future<bool> consumeSessionExpired() => _safe(
        () async => await _channel.invokeMethod<bool>('consumeSessionExpired') ?? false,
        false,
      );
}

/// Một instance dùng chung cho cả token storage lẫn scope thông báo: hàng đợi tuần tự (_serial) nằm trong instance,
/// nên hai instance riêng sẽ làm các lệnh ghi (setSession/clearSession/...) của hai bên có thể đảo thứ tự.
final NotificationBridge sharedNotificationBridge = NotificationBridge();
