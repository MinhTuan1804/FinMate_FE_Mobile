import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/assistant/domain/agent_answer.dart';
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
  Future<ChatReply> chat(
    String text, {
    String? accountId,
    String? clientRequestId,
    Map<String, dynamic>? itemContext,
  }) async {
    final response = await apiClient.post(
      '/api/v1/transactions/chat',
      data: {
        'text': text,
        if (itemContext != null) 'itemContext': itemContext,
        if (accountId != null) 'financialAccountId': accountId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      },
      fromJsonT: (json) => ChatReply.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? ChatReply.fromJson(const {});
  }

  /// Đánh giá một khoản định mua (chỉ đọc, không tạo giao dịch): kết luận do backend tính từ số dư và dự báo của người dùng
  /// Hỏi AI Financial Agent một câu về tài chính của chính người dùng (`POST /api/v1/agent/ask`, 1–500 ký tự).
  /// Lỗi: 422 `invalid_question`, 429 vượt hạn mức, 503 khi AI Service không dùng được trước khi có dữ liệu để trả lời.
  Future<AgentAnswer> askAgent(String question) async {
    final response = await apiClient.post(
      '/api/v1/agent/ask',
      data: {'question': question},
      // Agent gọi LLM hai lần (chọn công cụ + viết câu), mỗi lần tới ~10 giây khi Gemini chậm: hạn chờ mặc định 15 giây cắt ngang trước khi backend kịp trả bản dự phòng.
      receiveTimeout: const Duration(seconds: 45),
      fromJsonT: (json) => AgentAnswer.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const AgentAnswer(status: AgentAnswer.insufficientData);
  }

  /// Đánh giá mục tiêu tiết kiệm [targetVnd] trong [months] tháng qua đường đi thẳng (`POST /api/v1/agent/goal-plan`): backend chạy công cụ `goal_plan` luôn, không nhờ LLM chọn công cụ,
  /// nên vẫn có số liệu khi LLM chậm. Cùng dạng trả về với [askAgent]. Lỗi: 422 `invalid_goal`, 429 vượt hạn mức.
  Future<AgentAnswer> assessGoal(BigInt targetVnd, int months) async {
    final response = await apiClient.post(
      '/api/v1/agent/goal-plan',
      data: {'targetVnd': targetVnd.toInt(), 'months': months},
      receiveTimeout: const Duration(seconds: 30),
      fromJsonT: (json) => AgentAnswer.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const AgentAnswer(status: AgentAnswer.insufficientData);
  }

  /// Hẹn nhắc lúc 08:00 (giờ Việt Nam) của [date] để xem lại khoản định mua (`POST /forecast/purchase-reminders`). Trả false nếu đã hẹn ngày này rồi.
  /// Lỗi 422 `PURCHASE_REMINDER_INVALID_DATE` khi ngày không sau hôm nay hoặc quá 365 ngày.
  Future<bool> schedulePurchaseReminder(DateTime date) async {
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await apiClient.post(
      '/api/v1/forecast/purchase-reminders',
      data: {'date': day},
      fromJsonT: (json) => (json as Map<String, dynamic>)['created'] == true,
    );
    return response.data ?? false;
  }

  Future<PurchaseAssessment> purchaseCheck(PurchaseDraft draft) async {
    final date = draft.purchaseDate;
    final response = await apiClient.post(
      '/api/v1/forecast/purchase-check',
      data: {
        'amountCents': draft.amountCents.toInt(),
        if (draft.item != null) 'item': draft.item,
        if (draft.categorySlug != null) 'categorySlug': draft.categorySlug,
        if (date != null)
          'purchaseDate':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
      fromJsonT: (json) =>
          PurchaseAssessment.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        const PurchaseAssessment(verdict: 'insufficient_data', summary: '');
  }

  /// Gửi tệp ghi âm (multipart, field `file`): backend đổi giọng thành chữ rồi xử lý như câu chat (ưu tiên Rasa)
  Future<VoiceReply> voiceChat(
    String filePath, {
    String? accountId,
    String? clientRequestId,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
        contentType: DioMediaType('audio', 'mp4'),
      ),
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
      'file': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });
    final response = await apiClient.uploadFile(
      '/api/v1/chat/analyze-voice',
      formData: formData,
      fromJsonT: (json) => VoiceAnalysis.fromJson(json as Map<String, dynamic>),
    );
    return response.data ??
        const VoiceAnalysis(
          transcript: '',
          analysis: ChatAnalysis(intent: 'out_of_scope'),
        );
  }

  /// Phân tích một câu thành bản nháp (stateless, không lưu gì)
  Future<DraftTransaction> parse(
    String text, {
    DraftSource source = DraftSource.chat,
  }) async {
    final response = await apiClient.post(
      '/api/v1/transactions/parse',
      data: {'text': text},
      fromJsonT: (json) => DraftTransaction.fromParseJson(
        json as Map<String, dynamic>,
        source: source,
      ),
    );
    return response.data ?? DraftTransaction(source: source);
  }

  /// Gửi ảnh hóa đơn (multipart, field `file`) và nhận kết quả OCR
  Future<ReceiptScan> scanReceipt(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
      ),
    });
    final response = await apiClient.uploadFile(
      '/api/v1/transactions/scan-receipt',
      formData: formData,
      fromJsonT: (json) => ReceiptScan.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? ReceiptScan.fromJson(const {});
  }

  /// Câu gợi ý theo ngữ cảnh của người dùng; BE có thể trả rỗng. Bỏ các mục không có chữ.
  Future<List<AssistantSuggestion>> getSuggestions() async {
    final response = await apiClient.get(
      '/api/v1/assistant/suggestions',
      fromJsonT: (json) =>
          (json as List).map((e) => AssistantSuggestion.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return (response.data ?? const <AssistantSuggestion>[]).where((s) => s.text.trim().isNotEmpty).toList();
  }
}

/// Gợi ý cho khung chat trống. Chỉ là phần trang trí nên lỗi (mạng, 4xx, 5xx) cho ra danh sách rỗng
/// chứ không báo lỗi: không có gợi ý thì khung chat vẫn dùng được như cũ.
final assistantSuggestionsProvider = FutureProvider.autoDispose<List<AssistantSuggestion>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  try {
    return await ref.watch(assistantRepositoryProvider).getSuggestions();
  } on Object {
    return const [];
  }
});
