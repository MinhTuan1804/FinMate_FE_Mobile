/// DTO Wrapper chuẩn hóa toàn bộ phản hồi từ Backend FinMate.API
class ApiResponse<T> {
  final T? data;
  final ApiMeta? meta;
  final List<ApiError> errors;

  ApiResponse({
    this.data,
    this.meta,
    this.errors = const [],
  });

  bool get isSuccess => errors.isEmpty && data != null;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: json['meta'] != null ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>) : null,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => ApiError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ApiMeta {
  final String? nextCursor;

  ApiMeta({this.nextCursor});

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      nextCursor: (json['cursor'] ?? json['nextCursor']) as String?,
    );
  }
}

class ApiError {
  final String code;
  final String message;

  ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'Đã xảy ra lỗi không xác định.',
    );
  }
}
