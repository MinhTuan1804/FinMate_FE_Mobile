import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/support/data/support_repository.dart';
import 'package:finmate/features/support/domain/support.dart';

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicketEntity>>(
  (ref) => ref.watch(supportRepositoryProvider).listTickets(),
);

final supportAccessLogProvider = FutureProvider.autoDispose<List<SupportAccessLogEntity>>(
  (ref) => ref.watch(supportRepositoryProvider).accessLog(),
);

final ticketDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<TicketDetailController, AsyncValue<SupportTicketDetailEntity?>, String>(
  (ref, ticketId) => TicketDetailController(ref.watch(supportRepositoryProvider), ticketId)..load(),
);

/// Chi tiết 1 ca hỗ trợ: tải, trả lời, gửi ảnh, đóng, đánh giá. Mỗi lần gọi BE đều nhận một
/// `SupportTicketDetailEntity` MỚI (parse lại từ JSON), nên không gặp lại bẫy Riverpod so sánh
/// bằng-giá-trị đã rút ra ở Survey (không có chỗ nào cố tình emit lại CÙNG MỘT instance cũ).
class TicketDetailController extends StateNotifier<AsyncValue<SupportTicketDetailEntity?>> {
  TicketDetailController(this.repository, this.ticketId) : super(const AsyncValue.loading());

  final SupportRepository repository;
  final String ticketId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.getTicket(ticketId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reply(String body) async {
    state = AsyncValue.data(await repository.reply(ticketId, body));
  }

  /// Trả về tin nhắn mới nhất của khách sau khi gửi — màn hình dùng id của nó để gắn ảnh đính kèm.
  Future<SupportMessageEntity> replyAndReturn(String body) async {
    final detail = await repository.reply(ticketId, body);
    state = AsyncValue.data(detail);
    return detail.messages.last;
  }

  Future<void> addAttachment({required String messageId, required String filePath, required String fileName}) async {
    await repository.addAttachment(ticketId: ticketId, messageId: messageId, filePath: filePath, fileName: fileName);
    await load();
  }

  Future<void> close() async {
    final ticket = await repository.close(ticketId);
    final current = state.value;
    state = AsyncValue.data(
      current == null ? SupportTicketDetailEntity(ticket: ticket, messages: const []) : SupportTicketDetailEntity(ticket: ticket, messages: current.messages),
    );
  }

  Future<void> rate(int rating) async {
    final ticket = await repository.rate(ticketId, rating);
    final current = state.value;
    state = AsyncValue.data(
      current == null ? SupportTicketDetailEntity(ticket: ticket, messages: const []) : SupportTicketDetailEntity(ticket: ticket, messages: current.messages),
    );
  }
}

final accessRequestsControllerProvider = StateNotifierProvider.autoDispose
    .family<AccessRequestsController, AsyncValue<List<SupportAccessRequestEntity>>, String>(
  (ref, ticketId) => AccessRequestsController(ref.watch(supportRepositoryProvider), ticketId)..load(),
);

/// Danh sách yêu cầu xem dữ liệu của 1 ca: duyệt/từ chối/thu hồi, luôn tải lại toàn bộ danh sách
/// sau mỗi hành động (đơn giản, chắc đúng — danh sách này thường chỉ vài dòng).
class AccessRequestsController extends StateNotifier<AsyncValue<List<SupportAccessRequestEntity>>> {
  AccessRequestsController(this.repository, this.ticketId) : super(const AsyncValue.loading());

  final SupportRepository repository;
  final String ticketId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.listAccessRequests(ticketId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> approve(String requestId, {String? financialAccountId}) async {
    await repository.approveAccess(ticketId: ticketId, requestId: requestId, financialAccountId: financialAccountId);
    await load();
  }

  Future<void> deny(String requestId) async {
    await repository.denyAccess(ticketId: ticketId, requestId: requestId);
    await load();
  }

  Future<void> revoke(String requestId) async {
    await repository.revokeAccess(ticketId: ticketId, requestId: requestId);
    await load();
  }
}

/// Đọc nhãn lỗi ngắn gọn theo mã lỗi BE (không dùng statusCode — xem ghi chú ở FinanceMethods).
String supportErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'SUPPORT_DISABLED':
        return 'Tính năng hỗ trợ chưa được bật.';
      case 'SUPPORT_TOO_MANY_OPEN_TICKETS':
        return 'Bạn đang có quá nhiều yêu cầu chưa đóng.';
      case 'SUPPORT_TICKET_CLOSED':
        return 'Yêu cầu này đã đóng.';
      case 'SUPPORT_RATING_NOT_ALLOWED':
        return 'Chỉ đánh giá được khi yêu cầu đã giải quyết.';
      case 'SUPPORT_ATTACHMENTS_UNAVAILABLE':
        return 'Hiện chưa gửi được ảnh. Vui lòng mô tả bằng chữ.';
      case 'SUPPORT_ATTACHMENT_INVALID':
        return 'Ảnh không hợp lệ (chỉ nhận JPEG, PNG, WebP, HEIC, HEIF, tối đa 5MB).';
      case 'SUPPORT_TOO_MANY_ATTACHMENTS':
        return 'Tin nhắn này đã đủ số ảnh đính kèm cho phép.';
      case 'SUPPORT_ACCESS_REQUEST_NOT_PENDING':
        return 'Yêu cầu này không còn chờ bạn trả lời.';
      case 'SUPPORT_DRAFT_ACCOUNT_REQUIRED':
        return 'Vui lòng chọn ví để nhận giao dịch nháp.';
      default:
        return error.message;
    }
  }
  return error.toString();
}
