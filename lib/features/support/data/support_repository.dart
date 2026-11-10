import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/support/domain/support.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Dữ liệu ảnh đính kèm đã tải về: bytes thật (đã được BE giải mã từ bản mã hóa) + content-type.
class SupportAttachmentContent {
  final Uint8List data;
  final String contentType;

  const SupportAttachmentContent({required this.data, required this.contentType});
}

/// Phía khách của 2 nhóm route `/api/v1/support/tickets` và `/api/v1/support` (access-requests,
/// access-log). Phía vận hành (OpsCustomerDataService, duyệt theo ca) không thuộc app khách.
class SupportRepository {
  final ApiClient apiClient;

  SupportRepository({required this.apiClient});

  Future<SupportTicketDetailEntity> createTicket({
    required String category,
    required String subject,
    required String body,
  }) async {
    final res = await apiClient.post<SupportTicketDetailEntity>(
      '/api/v1/support/tickets',
      data: {'category': category, 'subject': subject, 'body': body},
      fromJsonT: (json) => SupportTicketDetailEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportTicketDetailEntity;
  }

  Future<List<SupportTicketEntity>> listTickets() async {
    final res = await apiClient.get<List<SupportTicketEntity>>(
      '/api/v1/support/tickets',
      fromJsonT: (json) =>
          (json as List).map((e) => SupportTicketEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? [];
  }

  Future<SupportTicketDetailEntity> getTicket(String ticketId) async {
    final res = await apiClient.get<SupportTicketDetailEntity>(
      '/api/v1/support/tickets/$ticketId',
      fromJsonT: (json) => SupportTicketDetailEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportTicketDetailEntity;
  }

  Future<SupportTicketDetailEntity> reply(String ticketId, String body) async {
    final res = await apiClient.post<SupportTicketDetailEntity>(
      '/api/v1/support/tickets/$ticketId/messages',
      data: {'body': body},
      fromJsonT: (json) => SupportTicketDetailEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportTicketDetailEntity;
  }

  /// Gửi ảnh đính kèm cho 1 tin nhắn của chính khách (field multipart tên `file`, khớp tên tham số
  /// `IFormFile file` phía BE). BE tự nhận dạng định dạng theo nội dung thật, không tin Content-Type client khai.
  Future<SupportAttachmentEntity> addAttachment({
    required String ticketId,
    required String messageId,
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await apiClient.uploadFile<SupportAttachmentEntity>(
      '/api/v1/support/tickets/$ticketId/messages/$messageId/attachments',
      formData: formData,
      fromJsonT: (json) => SupportAttachmentEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportAttachmentEntity;
  }

  /// Route này KHÔNG bọc trong envelope {success,data,error} như mọi route khác — BE trả file ảnh thô
  /// (`return File(content.Data, content.ContentType)`), nên không dùng `ApiClient.get` (luôn ép parse
  /// JSON envelope) mà gọi trực tiếp `apiClient.dio` với responseType bytes.
  Future<SupportAttachmentContent> getAttachmentBytes(String ticketId, String attachmentId) async {
    try {
      final response = await apiClient.dio.get<List<int>>(
        '/api/v1/support/tickets/$ticketId/attachments/$attachmentId',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      final contentType = response.headers.value('content-type') ?? 'application/octet-stream';
      return SupportAttachmentContent(data: bytes, contentType: contentType);
    } on DioException catch (e) {
      throw _decodeByteError(e);
    }
  }

  /// Lỗi của route trả bytes vẫn là JSON {error:{code,message}}, nhưng Dio nhận nó dưới dạng
  /// `List<int>` thô (vì responseType đã đặt là bytes) nên phải tự giải mã, không đi qua
  /// `ApiClient._handleError` (chỉ xử lý được response JSON đã parse sẵn).
  ApiException _decodeByteError(DioException e) {
    final raw = e.response?.data;
    if (raw is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
        final error = decoded['error'] as Map<String, dynamic>?;
        if (error != null) {
          return ApiException(
            message: error['message'] as String? ?? 'Đã xảy ra lỗi.',
            code: error['code'] as String?,
            statusCode: e.response?.statusCode,
          );
        }
      } catch (_) {
        // Không parse được thì rơi xuống thông báo chung ở dưới.
      }
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return NetworkException();
    }
    return ApiException(message: 'Không tải được ảnh. Vui lòng thử lại.', statusCode: e.response?.statusCode);
  }

  Future<SupportTicketEntity> close(String ticketId) async {
    final res = await apiClient.post<SupportTicketEntity>(
      '/api/v1/support/tickets/$ticketId/close',
      fromJsonT: (json) => SupportTicketEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportTicketEntity;
  }

  Future<SupportTicketEntity> rate(String ticketId, int rating) async {
    final res = await apiClient.post<SupportTicketEntity>(
      '/api/v1/support/tickets/$ticketId/rating',
      data: {'rating': rating},
      fromJsonT: (json) => SupportTicketEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportTicketEntity;
  }

  Future<List<SupportAccessRequestEntity>> listAccessRequests(String ticketId) async {
    final res = await apiClient.get<List<SupportAccessRequestEntity>>(
      '/api/v1/support/tickets/$ticketId/access-requests',
      fromJsonT: (json) =>
          (json as List).map((e) => SupportAccessRequestEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? [];
  }

  /// [financialAccountId] chỉ bắt buộc khi yêu cầu có phạm vi `Draft` (xem [SupportAccessRequestEntity.requiresDraftAccount]).
  Future<SupportAccessRequestEntity> approveAccess({
    required String ticketId,
    required String requestId,
    String? financialAccountId,
  }) async {
    final res = await apiClient.post<SupportAccessRequestEntity>(
      '/api/v1/support/tickets/$ticketId/access-requests/$requestId/approve',
      data: {if (financialAccountId != null) 'financialAccountId': financialAccountId},
      fromJsonT: (json) => SupportAccessRequestEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportAccessRequestEntity;
  }

  Future<SupportAccessRequestEntity> denyAccess({required String ticketId, required String requestId}) async {
    final res = await apiClient.post<SupportAccessRequestEntity>(
      '/api/v1/support/tickets/$ticketId/access-requests/$requestId/deny',
      fromJsonT: (json) => SupportAccessRequestEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportAccessRequestEntity;
  }

  /// Gọi lại khi đã Revoked vẫn hợp lệ (BE coi là no-op, không lỗi) — khách bấm thu hồi 2 lần không sao.
  Future<SupportAccessRequestEntity> revokeAccess({required String ticketId, required String requestId}) async {
    final res = await apiClient.post<SupportAccessRequestEntity>(
      '/api/v1/support/tickets/$ticketId/access-requests/$requestId/revoke',
      fromJsonT: (json) => SupportAccessRequestEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SupportAccessRequestEntity;
  }

  Future<List<SupportAccessLogEntity>> accessLog() async {
    final res = await apiClient.get<List<SupportAccessLogEntity>>(
      '/api/v1/support/access-log',
      fromJsonT: (json) =>
          (json as List).map((e) => SupportAccessLogEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? [];
  }
}
