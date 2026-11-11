import 'package:dio/dio.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/network/api_response.dart';
import 'package:finmate/core/network/auth_interceptor.dart';
import 'package:finmate/core/network/token_storage.dart';

/// Central HTTP API Client cho ứng dụng FinMate
class ApiClient {
  final Dio dio;
  final ITokenStorage tokenStorage;

  // Mặc định trỏ tới tunnel ngrok. Ghi đè khi cần:
  // --dart-define=API_BASE_URL=http://10.0.2.2:8080
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://finlike-lorrie-refreshfully.ngrok-free.dev',
  );

  ApiClient({
    String baseUrl = defaultBaseUrl,
    required this.tokenStorage,
    void Function()? onSessionExpired,
    Dio? customDio,
  }) : dio = customDio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                // Bỏ qua trang cảnh báo HTML của ngrok bản free (vô hại với backend thật)
                'ngrok-skip-browser-warning': 'true',
              },
            )) {
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      tokenStorage: tokenStorage,
      onSessionExpired: onSessionExpired,
    ));
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJsonT,
  }) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return _parse(response, fromJsonT);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJsonT,
  }) async {
    try {
      final response = await dio.post(path, data: data, queryParameters: queryParameters);
      return _parse(response, fromJsonT);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    required T Function(dynamic json) fromJsonT,
  }) async {
    try {
      final response = await dio.put(path, data: data);
      return _parse(response, fromJsonT);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    required T Function(dynamic json) fromJsonT,
  }) async {
    try {
      final response = await dio.patch(path, data: data);
      return _parse(response, fromJsonT);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String path, {dynamic data}) async {
    try {
      await dio.delete(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ApiResponse<T>> uploadFile<T>(
    String path, {
    required FormData formData,
    required T Function(dynamic json) fromJsonT,
  }) async {
    try {
      final response = await dio.post(
        path,
        data: formData,
        // OCR hóa đơn mất 5-35 giây (đo trên máy thật); chờ 15 giây như lệnh thường thì app báo "mất mạng" dù backend vẫn xử lý xong.
        options: Options(contentType: 'multipart/form-data', receiveTimeout: const Duration(seconds: 90), sendTimeout: const Duration(seconds: 60)),
      );
      return _parse(response, fromJsonT);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Parse phản hồi chuẩn; nếu server trả về không phải JSON (HTML từ proxy/tunnel, lỗi 502...)
  /// thì ném ApiException thân thiện thay vì lỗi ép kiểu.
  ApiResponse<T> _parse<T>(Response response, T Function(dynamic json) fromJsonT) {
    final body = response.data;
    // 204 No Content (ví dụ resend-verification) hoặc body rỗng: thành công, không có dữ liệu
    if (body == null || (body is String && body.trim().isEmpty)) return ApiResponse<T>();
    if (body is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Máy chủ trả về dữ liệu không hợp lệ. Vui lòng thử lại sau.',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
    try {
      return ApiResponse.fromJson(body, fromJsonT);
    } on Object {
      throw ApiException(
        message: 'Không đọc được dữ liệu từ máy chủ. Vui lòng thử lại sau.',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
  }

  ApiException _handleError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return NetworkException();
    }

    final response = err.response;
    final status = response?.statusCode;
    final data = response?.data;

    String? code;
    String? message;
    if (data is Map<String, dynamic>) {
      // Lỗi validation tự động của ASP.NET (ProblemDetails): errors là map {trường: [thông điệp]}
      final fieldErrors = data['errors'];
      if (fieldErrors is Map) {
        final first = fieldErrors.values.expand((v) => v is List ? v : [v]).firstOrNull;
        code = 'VALIDATION';
        message = first == null ? 'Dữ liệu không hợp lệ.' : 'Dữ liệu không hợp lệ: $first';
      } else {
        // Backend trả lỗi dạng {"error": {code, message}}; chấp nhận thêm dạng mảng {"errors": [...]}
        final errors = data['errors'];
        final firstError = errors is List && errors.isNotEmpty && errors.first is Map<String, dynamic>
            ? errors.first as Map<String, dynamic>
            : (data['error'] is Map<String, dynamic> ? data['error'] as Map<String, dynamic> : null);
        if (firstError != null) {
          code = firstError['code'] as String?;
          message = firstError['message'] as String? ?? 'Yêu cầu không hợp lệ.';
          // Lỗi validation: kèm thông điệp chi tiết của trường đầu tiên (details: [{field, message}])
          final details = firstError['details'];
          if (details is List && details.isNotEmpty && details.first is Map && (details.first as Map)['message'] is String) {
            message = '$message ${(details.first as Map)['message']}';
          }
        }
      }
    }

    if (status == 401) {
      // Đăng nhập sai thông tin không phải là "phiên hết hạn"
      if (err.requestOptions.path.contains('/auth/login')) {
        return ApiException(
          message: message ?? 'Email hoặc mật khẩu không chính xác.',
          code: code ?? 'INVALID_CREDENTIALS',
          statusCode: 401,
        );
      }
      return UnauthorizedException();
    }

    if (status == 403) {
      return ForbiddenException(message: message ?? 'Bạn không có quyền thực hiện hành động này.', code: code);
    }

    if (status == 404) {
      return NotFoundException(message: message ?? 'Không tìm thấy dữ liệu yêu cầu.', code: code);
    }

    if (status == 409) {
      return ConflictException(message: message ?? 'Dữ liệu đã bị thay đổi hoặc xung đột. Vui lòng thử lại.', code: code);
    }

    if (status == 422) {
      return BusinessRuleException(code: code, message: message ?? 'Yêu cầu không hợp lệ.');
    }

    if (status == 400 && message != null) {
      return BusinessRuleException(code: code, message: message, statusCode: 400);
    }

    return ApiException(
      message: message ??
          (status != null && status >= 500
              ? 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'
              : 'Yêu cầu không thành công. Vui lòng thử lại.'),
      code: code,
      statusCode: status,
    );
  }
}
