import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(apiClient: ref.watch(apiClientProvider)),
);

/// API AI của backend: chatbot, phân tích câu và quét hóa đơn.
/// Không có dữ liệu giả: mọi lỗi (mạng, 4xx, 5xx, AI service không sẵn sàng) được ném lại.
class AssistantRepository {
  final ApiClient apiClient;

  AssistantRepository({required this.apiClient});

  /// `clientRequestId` giúp backend chống trùng khi người dùng gửi lại cùng một tin nhắn
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async {
    final response = await apiClient.post(
      '/api/v1/transactions/chat',
      data: {
        'text': text,
        if (accountId != null) 'financialAccountId': accountId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      },
      fromJsonT: (json) => ChatReply.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? ChatReply.fromJson(const {});
  }

  /// Gửi tệp ghi âm (multipart, field `file`): backend đổi giọng thành chữ rồi xử lý như câu chat (ưu tiên Rasa)
  Future<VoiceReply> voiceChat(String filePath, {String? accountId, String? clientRequestId}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: p.basename(filePath), contentType: DioMediaType('audio', 'mp4')),
      if (accountId != null) 'financialAccountId': accountId,
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
    });
    final response = await apiClient.uploadFile(
      '/api/v1/transactions/voice',
      formData: formData,
      fromJsonT: (json) => VoiceReply.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? VoiceReply.fromJson(const {});
  }

  /// Chỉ HIỂU câu (không ghi gì, không đọc dữ liệu cá nhân): app tự quyết định ghi hay hỏi bằng dữ liệu trên máy
  Future<ChatAnalysis> analyze(String text) async {
    final response = await apiClient.post(
      '/api/v1/chat/analyze',
      data: {'text': text},
      fromJsonT: (json) => ChatAnalysis.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const ChatAnalysis(intent: 'out_of_scope');
  }

  /// Ghi âm -> chữ -> hiểu câu, vẫn không ghi gì phía server
  Future<VoiceAnalysis> analyzeVoice(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: p.basename(filePath), contentType: DioMediaType('audio', 'mp4')),
    });
    final response = await apiClient.uploadFile(
      '/api/v1/chat/analyze-voice',
      formData: formData,
      fromJsonT: (json) => VoiceAnalysis.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const VoiceAnalysis(transcript: '', analysis: ChatAnalysis(intent: 'out_of_scope'));
  }

  /// Phân tích một câu thành bản nháp (stateless, không lưu gì)
  Future<DraftTransaction> parse(String text, {DraftSource source = DraftSource.chat}) async {
    final response = await apiClient.post(
      '/api/v1/transactions/parse',
      data: {'text': text},
      fromJsonT: (json) => DraftTransaction.fromParseJson(json as Map<String, dynamic>, source: source),
    );
    return response.data ?? DraftTransaction(source: source);
  }

  /// Gửi ảnh hóa đơn (multipart, field `file`) và nhận kết quả OCR
  Future<ReceiptScan> scanReceipt(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: p.basename(filePath)),
    });
    final response = await apiClient.uploadFile(
      '/api/v1/transactions/scan-receipt',
      formData: formData,
      fromJsonT: (json) => ReceiptScan.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? ReceiptScan.fromJson(const {});
  }
}
