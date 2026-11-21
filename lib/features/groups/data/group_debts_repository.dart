import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/core/widgets/cursor_pager.dart';

final groupDebtsRepositoryProvider = Provider<GroupDebtsRepository>(
  (ref) => GroupDebtsRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Hóa đơn chia, sổ nợ, nhắc nợ và duyệt khoản lớn của nhóm (`/api/v1/groups/{id}/...`).
/// FinMate chỉ ghi nhận số nợ và việc đã trả, KHÔNG chuyển tiền thật.
class GroupDebtsRepository {
  final ApiClient apiClient;
  GroupDebtsRepository({required this.apiClient});

  /// Một trang hóa đơn mới nhất trước. [cursor] lấy từ trang trước nếu cần phân trang.
  Future<CursorPageResult<GroupBillEntity>> getBills(String groupId, {int limit = 20, String? cursor}) async {
    final res = await apiClient.get<List<GroupBillEntity>>(
      '/api/v1/groups/$groupId/bills',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      fromJsonT: (json) => (json as List).map((e) => GroupBillEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return (items: res.data ?? const <GroupBillEntity>[], nextCursor: res.meta?.nextCursor);
  }

  /// `Equal`: chỉ cần userId (server tự chia, dồn phần dư cho người trả). `Custom`: tổng shareCents phải bằng [amountCents]
  /// (lỗi 422 GROUP_BILL_SPLIT_MISMATCH). Quyền ShareTransactions — Viewer bị 403.
  /// HTTP 202 = yêu cầu chờ duyệt (khoản từ ngưỡng do người không phải chủ nhóm tạo), KHÔNG phải hóa đơn.
  Future<GroupBillCreateResult> createBill({
    required String groupId,
    required String title,
    required BigInt amountCents,
    required String paidByUserId,
    required String splitMode,
    required List<GroupBillSplitInput> splits,
    DateTime? occurredAt,
    String? groupCategoryId,
    String? note,
  }) async {
    final res = await apiClient.post<Map<String, dynamic>>(
      '/api/v1/groups/$groupId/bills',
      data: {
        'title': title,
        'amountCents': amountCents.toInt(),
        'paidByUserId': paidByUserId,
        'splitMode': splitMode,
        if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
        'splits': splits.map((s) => s.toJson()).toList(),
        if (groupCategoryId != null) 'groupCategoryId': groupCategoryId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      fromJsonT: (json) => json as Map<String, dynamic>,
    );
    final body = res.data as Map<String, dynamic>;
    return res.statusCode == 202
        ? GroupBillCreateResult.pending(GroupApprovalEntity.fromJson(body))
        : GroupBillCreateResult.created(GroupBillEntity.fromJson(body));
  }

  /// Số nợ ròng từng thành viên + gợi ý các lượt chuyển tối giản (null nếu nhóm chọn cấn trừ thủ công).
  Future<GroupBalancesEntity> getBalances(String groupId) async {
    final res = await apiClient.get<GroupBalancesEntity>(
      '/api/v1/groups/$groupId/balances',
      fromJsonT: (json) => GroupBalancesEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupBalancesEntity;
  }

  /// Ghi nhận đã trả nợ. Chỉ người trả, người nhận hoặc chủ nhóm; vượt số đang nợ 422 GROUP_SETTLEMENT_EXCEEDS_DEBT.
  Future<GroupSettlementEntity> settle({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required BigInt amountCents,
    String? note,
  }) async {
    final res = await apiClient.post<GroupSettlementEntity>(
      '/api/v1/groups/$groupId/settlements',
      data: {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amountCents': amountCents.toInt(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
      fromJsonT: (json) => GroupSettlementEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupSettlementEntity;
  }

  /// Nhắc một người đang nợ. Mỗi người tối đa 1 lần/24 giờ/nhóm (429 GROUP_REMINDER_COOLDOWN); người không nợ 422 GROUP_NO_DEBT.
  Future<GroupReminderResult> remindDebt({required String groupId, required String userId}) async {
    final res = await apiClient.post<GroupReminderResult>(
      '/api/v1/groups/$groupId/members/$userId/remind-debt',
      fromJsonT: (json) => GroupReminderResult.fromJson(json as Map<String, dynamic>),
    );
    return res.data ?? const GroupReminderResult();
  }

  /// "Nhắc thanh toán một chạm": nhắc mọi người còn nợ, cùng giới hạn tần suất.
  Future<GroupReminderResult> remindAll(String groupId) async {
    final res = await apiClient.post<GroupReminderResult>(
      '/api/v1/groups/$groupId/remind-all',
      fromJsonT: (json) => GroupReminderResult.fromJson(json as Map<String, dynamic>),
    );
    return res.data ?? const GroupReminderResult();
  }

  /// [status]: Pending | Approved | Rejected | All. Chủ nhóm thấy tất cả, người khác chỉ thấy yêu cầu của mình.
  Future<List<GroupApprovalEntity>> getApprovals(String groupId, {String status = 'Pending'}) async {
    final res = await apiClient.get<List<GroupApprovalEntity>>(
      '/api/v1/groups/$groupId/approvals',
      queryParameters: {'status': status},
      fromJsonT: (json) => (json as List).map((e) => GroupApprovalEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  /// Chỉ chủ nhóm. Xử lý lần hai: 422 GROUP_APPROVAL_NOT_PENDING.
  Future<GroupApprovalEntity> approve({required String groupId, required String approvalId}) async {
    final res = await apiClient.post<GroupApprovalEntity>(
      '/api/v1/groups/$groupId/approvals/$approvalId/approve',
      fromJsonT: (json) => GroupApprovalEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupApprovalEntity;
  }

  Future<GroupApprovalEntity> reject({required String groupId, required String approvalId, String? reason}) async {
    final res = await apiClient.post<GroupApprovalEntity>(
      '/api/v1/groups/$groupId/approvals/$approvalId/reject',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      fromJsonT: (json) => GroupApprovalEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupApprovalEntity;
  }
}
