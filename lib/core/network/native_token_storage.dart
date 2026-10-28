import '../native/notification_bridge.dart';
import 'token_storage.dart';

/// Interface riêng (không nhét vào ITokenStorage) để các lớp implements ITokenStorage sẵn có không vỡ.
abstract interface class NativeRefresher {
  Future<NativeRefreshResult> refreshViaNative({String? staleAccessToken});
}

/// ITokenStorage mỏng trên kênh native; native là owner duy nhất của token.
class NativeTokenStorage implements ITokenStorage, NativeRefresher {
  NativeTokenStorage({
    required this._bridge,
    required this._legacy,
    required this._baseUrl,
  });

  final NotificationBridge _bridge;
  final ITokenStorage _legacy;
  final String _baseUrl;
  Future<void>? _migration;

  // Chạy lười đúng một lần trước mọi phương thức; lỗi thì cho phép thử lại lần sau.
  Future<void> _ready() => _migration ??= _migrate().catchError((Object e) {
        _migration = null;
        throw e;
      });

  // Người đang đăng nhập bằng flutter_secure_storage: chép sang native rồi xóa bên cũ để khỏi bị đăng xuất.
  Future<void> _migrate() async {
    final nativeToken = await _bridge.getAccessToken();
    // Native đã có token thì bản legacy chỉ còn là token đã bị xoay: xóa luôn, nếu để lại thì lần sau native rỗng
    // sẽ chép nó sang và dùng lại refresh token đã thu hồi (BE thu hồi mọi phiên).
    if (nativeToken != null && nativeToken.isNotEmpty) {
      await _clearLegacy();
      return;
    }
    final access = await _legacy.getAccessToken();
    final refresh = await _legacy.getRefreshToken();
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) return;
    await _bridge.setSession(baseUrl: _baseUrl, accessToken: access, refreshToken: refresh);
    await _clearLegacy();
  }

  // Lỗi xóa legacy không được làm hỏng việc di chuyển (native đã giữ token); lần mở sau sẽ dọn lại.
  Future<void> _clearLegacy() async {
    try {
      await _legacy.clearTokens();
    } catch (_) {}
  }

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _ready();
    await _bridge.setSession(baseUrl: _baseUrl, accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<String?> getAccessToken() async {
    await _ready();
    return _bridge.getAccessToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    await _ready();
    return _bridge.getRefreshToken();
  }

  @override
  Future<void> clearTokens() async {
    await _ready();
    await _bridge.clearSession();
    await _legacy.clearTokens();
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<NativeRefreshResult> refreshViaNative({String? staleAccessToken}) async {
    await _ready();
    return _bridge.refreshSession(staleAccessToken: staleAccessToken);
  }
}
