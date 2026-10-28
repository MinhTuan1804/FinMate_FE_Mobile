import 'package:dio/dio.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/network/native_token_storage.dart';
import 'package:finmate/core/network/token_storage.dart';

/// Interceptor tự động đính kèm Access Token và thực hiện Refresh Token Rotation khi gặp 401
class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  final ITokenStorage tokenStorage;
  final void Function()? onSessionExpired;

  AuthInterceptor({
    required this.dio,
    required this.tokenStorage,
    this.onSessionExpired,
  });

  /// Các endpoint công khai: không đính kèm token và không kích hoạt refresh khi 401
  static const _publicEndpoints = [
    '/api/v1/auth/login',
    '/api/v1/auth/register',
    '/api/v1/auth/google',
    '/api/v1/auth/refresh',
    '/api/v1/auth/verify-email',
    '/api/v1/auth/forgot-password',
    '/api/v1/auth/reset-password',
    '/api/v1/auth/resend-verification',
  ];

  static bool _isPublic(String path) => _publicEndpoints.any(path.contains);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isPublic(options.path)) {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  /// Dio không có interceptor, dùng cho refresh/retry để tránh vòng lặp và deadlock của QueuedInterceptor
  Dio _plainDio(String baseUrl) {
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ))..httpClientAdapter = dio.httpClientAdapter;
  }

  Future<void> _expireSession() async {
    await tokenStorage.clearTokens();
    onSessionExpired?.call();
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _isPublic(options.path)) {
      return handler.next(err);
    }

    final plain = _plainDio(options.baseUrl);
    final storage = tokenStorage;

    // Android là nơi duy nhất được gọi /auth/refresh (backend xoay refresh token, dùng lại là bị thu hồi cả phiên).
    if (storage is NativeRefresher) {
      final header = options.headers['Authorization'];
      final stale = header is String && header.startsWith('Bearer ') ? header.substring(7) : null;
      NativeRefreshResult result;
      try {
        result = await (storage as NativeRefresher).refreshViaNative(staleAccessToken: stale);
      } catch (_) {
        // Lỗi kênh native không phải bằng chứng hết phiên: coi như lỗi tạm thời.
        result = const NativeRefreshResult(NativeRefreshStatus.network);
      }
      final newToken = result.accessToken;
      if (result.status == NativeRefreshStatus.expired) {
        await _expireSession();
        return handler.next(err);
      }
      if (result.status != NativeRefreshStatus.ok || newToken == null || newToken.isEmpty) {
        return handler.next(DioException(requestOptions: options, type: DioExceptionType.connectionError));
      }
      try {
        options.headers['Authorization'] = 'Bearer $newToken';
        return handler.resolve(await plain.fetch(options));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expireSession();
      return handler.next(err);
    }

    String newAccessToken;
    try {
      final response = await plain.post(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      newAccessToken = data['accessToken'] as String;
      await tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: data['refreshToken'] as String,
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401 || code == 403) {
        // Refresh token không hợp lệ hoặc đã bị tái sử dụng (server thu hồi token)
        await _expireSession();
        return handler.next(err);
      }
      // Lỗi mạng/timeout/5xx: giữ nguyên phiên, chỉ báo lỗi cho request hiện tại
      return handler.next(e);
    } catch (_) {
      // Phản hồi refresh sai định dạng
      await _expireSession();
      return handler.next(err);
    }

    try {
      options.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await plain.fetch(options);
      return handler.resolve(retryResponse);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
