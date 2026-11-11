/// Exception phân loại chi tiết các lỗi mạng và lỗi nghiệp vụ từ server
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException({required this.message, this.code, this.statusCode});

  @override
  String toString() => 'ApiException(code: $code, message: $message, status: $statusCode)';
}

/// Lỗi vi phạm quy tắc nghiệp vụ (422 từ BusinessRuleException backend, hoặc 400 từ lỗi validate)
class BusinessRuleException extends ApiException {
  BusinessRuleException({required super.message, required super.code, int statusCode = 422})
      : super(statusCode: statusCode);
}

/// Lỗi xác thực hoặc hết hạn phiên làm việc (401)
class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'})
      : super(code: 'UNAUTHORIZED', statusCode: 401);
}

/// Lỗi không có quyền thực hiện hành động (403 từ ForbiddenException backend)
class ForbiddenException extends ApiException {
  ForbiddenException({required super.message, super.code})
      : super(statusCode: 403);
}

/// Lỗi không tìm thấy dữ liệu (404 từ NotFoundException backend)
class NotFoundException extends ApiException {
  NotFoundException({required super.message, super.code})
      : super(statusCode: 404);
}

/// Lỗi xung đột dữ liệu, ví dụ cập nhật đồng thời (409 từ ConflictException backend)
class ConflictException extends ApiException {
  ConflictException({required super.message, super.code})
      : super(statusCode: 409);
}

/// Lỗi mất kết nối mạng hoặc timeout
class NetworkException extends ApiException {
  NetworkException({super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.'})
      : super(code: 'NETWORK_ERROR');
}

/// Chuyển mọi lỗi thành thông điệp thân thiện để hiển thị cho người dùng
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is Exception) return error.toString().replaceFirst('Exception: ', '');
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}
