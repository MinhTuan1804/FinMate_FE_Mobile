/// Exception phân loại chi tiết các lỗi mạng và lỗi nghiệp vụ từ server
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException({required this.message, this.code, this.statusCode});

  @override
  String toString() => 'ApiException(code: $code, message: $message, status: $statusCode)';
}

/// Lỗi vi phạm quy tắc nghiệp vụ (400 / 422 từ BusinessRuleException backend)
class BusinessRuleException extends ApiException {
  BusinessRuleException({required super.message, required super.code})
      : super(statusCode: 400);
}

/// Lỗi xác thực hoặc hết hạn phiên làm việc (401)
class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'})
      : super(code: 'UNAUTHORIZED', statusCode: 401);
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
