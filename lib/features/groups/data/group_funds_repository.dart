import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/domain/group_fund.dart';
import 'package:finmate/core/widgets/cursor_pager.dart';

/// Quỹ chung ảo của nhóm (Phase 85) — `/api/v1/groups/{groupId}/funds...`. Đọc (danh sách/tổng kết/sổ
/// quỹ), ghi dòng quỹ (Nạp quỹ/Ghi khoản chi ở I3) và tạo quỹ (I7, ManageFunds). Lưu trữ quỹ vẫn
/// chưa có màn — chưa cần cho đợt I1-I7 (chỉ tạo đúng 1 quỹ dùng chung là đủ).
final groupFundsRepositoryProvider = Provider<GroupFundsRepository>(
  (ref) => GroupFundsRepository(apiClient: ref.watch(apiClientProvider)),
);

class GroupFundsRepository {
  final ApiClient apiClient;
  GroupFundsRepository({required this.apiClient});

  /// Quỹ đang dùng trước, rồi đến quỹ đã lưu trữ.
  Future<List<GroupFundEntity>> getFunds(String groupId) async {
    final res = await apiClient.get<List<GroupFundEntity>>(
      '/api/v1/groups/$groupId/funds',
      fromJsonT: (json) => (json as List).map((e) => GroupFundEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  /// Tối đa `groups.maxFundsPerGroup` (mặc định 3) quỹ chưa lưu trữ — vượt thì 422 `GROUP_TOO_MANY_FUNDS`.
  Future<GroupFundEntity> createFund({required String groupId, required String name, String? note}) async {
    final res = await apiClient.post<GroupFundEntity>(
      '/api/v1/groups/$groupId/funds',
      data: {'name': name, if (note != null && note.isNotEmpty) 'note': note},
      fromJsonT: (json) => GroupFundEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupFundEntity;
  }

  Future<GroupFundEntity> getFund({required String groupId, required String fundId}) async {
    final res = await apiClient.get<GroupFundEntity>(
      '/api/v1/groups/$groupId/funds/$fundId',
      fromJsonT: (json) => GroupFundEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupFundEntity;
  }

  /// [year]/[month] null = tháng này (giờ Việt Nam, theo BE).
  Future<GroupFundSummaryEntity> getFundSummary({required String groupId, required String fundId, int? year, int? month}) async {
    final res = await apiClient.get<GroupFundSummaryEntity>(
      '/api/v1/groups/$groupId/funds/$fundId/summary',
      queryParameters: {
        if (year != null) 'year': year,
        if (month != null) 'month': month,
      },
      fromJsonT: (json) => GroupFundSummaryEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupFundSummaryEntity;
  }

  /// Sổ quỹ, mới nhất trước; [kind] lọc theo loại dòng ('Contribution'/'Expense'/'Withdrawal'/'Adjustment').
  Future<CursorPageResult<GroupFundEntryEntity>> getFundEntries({
    required String groupId,
    required String fundId,
    String? cursor,
    int limit = 20,
    String? kind,
    String? memberId,
  }) async {
    final res = await apiClient.get<List<GroupFundEntryEntity>>(
      '/api/v1/groups/$groupId/funds/$fundId/entries',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (kind != null) 'kind': kind,
        if (memberId != null) 'memberId': memberId,
      },
      fromJsonT: (json) => (json as List).map((e) => GroupFundEntryEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return (items: res.data ?? const <GroupFundEntryEntity>[], nextCursor: res.meta?.nextCursor);
  }

  /// Ghi một dòng quỹ mới (`kind` = Contribution/Expense/Withdrawal/Adjustment). `Expense` bắt buộc
  /// [categoryId] hoặc [groupCategoryId]. Không gửi `financialAccountId`/`fromTransactionId` — đợt
  /// I1-I7 chưa có chọn ví, chỉ ghi sổ quỹ thuần.
  ///
  /// Trả về null khi server trả HTTP 202: khoản chi/rút từ ngưỡng do người không phải chủ nhóm tạo chỉ là YÊU CẦU
  /// chờ chủ nhóm duyệt (chưa trừ quỹ). App phải báo "đã gửi, chờ duyệt" thay vì "đã ghi".
  Future<GroupFundEntryEntity?> createEntry({
    required String groupId,
    required String fundId,
    required GroupFundEntryKind kind,
    required BigInt amountCents,
    String? categoryId,
    String? groupCategoryId,
    String? note,
    String? merchantName,
  }) async {
    final res = await apiClient.post<GroupFundEntryEntity?>(
      '/api/v1/groups/$groupId/funds/$fundId/entries',
      data: {
        'kind': kind.apiValue,
        'amountCents': amountCents.toInt(),
        if (categoryId != null) 'categoryId': categoryId,
        if (groupCategoryId != null) 'groupCategoryId': groupCategoryId,
        if (note != null && note.isNotEmpty) 'note': note,
        if (merchantName != null && merchantName.isNotEmpty) 'merchantName': merchantName,
      },
      fromJsonT: (json) {
        final map = json as Map<String, dynamic>;
        // 202: thân là yêu cầu chờ duyệt (không có khóa `entry`)
        return map['entry'] == null ? null : GroupFundEntryEntity.fromJson(map['entry'] as Map<String, dynamic>);
      },
    );
    return res.statusCode == 202 ? null : res.data;
  }
}
