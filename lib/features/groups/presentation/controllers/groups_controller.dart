import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_funds_repository.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/data/group_debts_repository.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/domain/group_extras.dart';
import 'package:finmate/features/groups/domain/group_fund.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/core/widgets/cursor_pager.dart';

/// Danh sách nhóm của người dùng hiện tại. Tự tạo lại (và tải lại) khi đổi người dùng;
/// chưa đăng nhập thì rỗng và không gọi API.
final groupsControllerProvider = StateNotifierProvider<GroupsController, AsyncValue<List<GroupEntity>>>((ref) {
  final signedIn = ref.watch(currentUserIdProvider) != null;
  return GroupsController(repository: ref.watch(groupsRepositoryProvider), enabled: signedIn);
});

/// Chi tiết một nhóm (thẻ thông tin, vai trò/quyền của mình).
final groupDetailProvider = FutureProvider.autoDispose.family<GroupEntity, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getGroup(groupId),
);

/// Thành viên của một nhóm.
final groupMembersProvider = FutureProvider.autoDispose.family<List<GroupMemberEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getMembers(groupId),
);

/// Nhật ký hoạt động của một nhóm.
final groupActivitiesProvider = FutureProvider.autoDispose.family<List<GroupActivityEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getActivities(groupId),
);

/// Mã/link tham gia chung của nhóm (người có quyền mời xem được).
final groupJoinLinkProvider = FutureProvider.autoDispose.family<GroupJoinLinkEntity, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getJoinLink(groupId),
);

/// Lời mời đang chờ của một nhóm (chủ nhóm/quản lý xem được).
final groupInvitationsProvider = FutureProvider.autoDispose.family<List<GroupInvitationEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getInvitations(groupId),
);

/// Giao dịch đã chia sẻ trong nhóm (tháng hiện tại theo mặc định của BE).
final groupTransactionsProvider = FutureProvider.autoDispose.family<List<GroupTransactionEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getTransactions(groupId: groupId),
);

/// Báo cáo tổng thu chi tháng hiện tại của nhóm.
final groupMonthlyReportProvider = FutureProvider.autoDispose.family<GroupMonthlyReportEntity, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getMonthlyReport(groupId: groupId),
);

/// Danh mục riêng của nhóm (dùng để phân loại lại giao dịch đã chia sẻ).
final groupCategoriesProvider = FutureProvider.autoDispose.family<List<GroupCategoryEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getCategories(groupId),
);

/// Quy tắc tự chia sẻ giao dịch của chính mình vào nhóm.
final groupShareRulesProvider = FutureProvider.autoDispose.family<List<GroupShareRuleEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getShareRules(groupId),
);

/// Ngân sách của nhóm.
final groupBudgetsProvider = FutureProvider.autoDispose.family<List<GroupBudgetEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getBudgets(groupId),
);

/// Mục tiêu nhóm.
final groupGoalsProvider = FutureProvider.autoDispose.family<List<SavingsGoalEntity>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getGoals(groupId),
);

/// Các lần góp tiền vào một mục tiêu nhóm; khóa là (groupId, goalId).
final groupGoalContributionsProvider =
    FutureProvider.autoDispose.family<List<GroupContributionEntity>, (String groupId, String goalId)>(
  (ref, key) => ref.watch(groupsRepositoryProvider).getGoalContributions(groupId: key.$1, goalId: key.$2),
);

/// Quỹ chung của một nhóm (Phase 85); rỗng nếu tính năng quỹ tắt hoặc nhóm chưa có quỹ nào —
/// lỗi (vd GROUPS_DISABLED/GROUP_FUNDS_DISABLED) không ném ra màn hình, chỉ coi như không có quỹ.
final groupFundsProvider = FutureProvider.autoDispose.family<List<GroupFundEntity>, String>((ref, groupId) async {
  try {
    return await ref.watch(groupFundsRepositoryProvider).getFunds(groupId);
  } catch (_) {
    return const [];
  }
});

/// Quỹ chung chưa lưu trữ đầu tiên của nhóm (quỹ chính dùng để hiện số dư tóm tắt ở I1/I4); null nếu
/// không có quỹ nào đang dùng.
final groupPrimaryFundProvider = FutureProvider.autoDispose.family<GroupFundEntity?, String>((ref, groupId) async {
  final funds = await ref.watch(groupFundsProvider(groupId).future);
  for (final f in funds) {
    if (!f.isArchived) return f;
  }
  return null;
});

/// Tổng kết tháng này của một quỹ; khóa là (groupId, fundId).
final groupFundSummaryProvider =
    FutureProvider.autoDispose.family<GroupFundSummaryEntity, (String groupId, String fundId)>(
  (ref, key) => ref.watch(groupFundsRepositoryProvider).getFundSummary(groupId: key.$1, fundId: key.$2),
);

/// Sổ quỹ (entries) của một quỹ; khóa là (groupId, fundId).
final groupFundEntriesProvider = StateNotifierProvider.autoDispose
    .family<CursorPager<GroupFundEntryEntity>, AsyncValue<List<GroupFundEntryEntity>>, (String groupId, String fundId)>((ref, key) {
  final repo = ref.watch(groupFundsRepositoryProvider);
  return CursorPager((cursor) => repo.getFundEntries(groupId: key.$1, fundId: key.$2, limit: 50, cursor: cursor));
});

/// Hóa đơn chia của nhóm (mới nhất trước, tải thêm theo cursor).
final groupBillsProvider =
    StateNotifierProvider.autoDispose.family<CursorPager<GroupBillEntity>, AsyncValue<List<GroupBillEntity>>, String>((ref, groupId) {
  final repo = ref.watch(groupDebtsRepositoryProvider);
  return CursorPager((cursor) => repo.getBills(groupId, cursor: cursor));
});

/// Chi tiết một hóa đơn nhóm (kèm phần chia từng người); khóa là (groupId, billId).
final groupBillDetailProvider = FutureProvider.autoDispose.family<GroupBillEntity, (String groupId, String billId)>(
  (ref, key) => ref.watch(groupDebtsRepositoryProvider).getBill(key.$1, key.$2),
);

/// Số nợ ròng từng thành viên và gợi ý cấn trừ.
final groupBalancesProvider = FutureProvider.autoDispose.family<GroupBalancesEntity, String>(
  (ref, groupId) => ref.watch(groupDebtsRepositoryProvider).getBalances(groupId),
);

/// Yêu cầu chờ duyệt (chủ nhóm thấy của mọi người, người khác chỉ thấy của mình).
final groupApprovalsProvider = FutureProvider.autoDispose.family<List<GroupApprovalEntity>, String>(
  (ref, groupId) => ref.watch(groupDebtsRepositoryProvider).getApprovals(groupId),
);

/// Gợi ý "Gần đây" khi mời: người cùng nhóm khác, chưa ở nhóm này.
final inviteSuggestionsProvider = FutureProvider.autoDispose.family<List<InviteSuggestion>, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getInviteSuggestions(groupId),
);

/// Cài đặt của một nhóm (ngày chốt sổ, duyệt khoản lớn, thông báo...). Mọi thành viên đọc được, chỉ chủ nhóm sửa.
final groupSettingsProvider = FutureProvider.autoDispose.family<GroupSettingsEntity, String>(
  (ref, groupId) => ref.watch(groupsRepositoryProvider).getSettings(groupId),
);

/// Tổng quan của tôi cho hero card I1: tổng chi tháng này, phần cần đóng, số cần thanh toán, hạn chốt sổ gần nhất.
final groupsSummaryProvider = FutureProvider.autoDispose<GroupsSummaryEntity>(
  (ref) => ref.watch(groupsRepositoryProvider).getMySummary(),
);

/// Tổng chi tháng này cộng dồn trên MỌI nhóm đang tham gia (cách cũ, tự cộng từng nhóm; I1 giờ dùng [groupsSummaryProvider]).
/// Gọi report từng nhóm song song; nhóm nào lỗi (API tắt, quyền thiếu) bị bỏ qua, không chặn cả màn.
final allGroupsMonthlySpendProvider = FutureProvider.autoDispose<BigInt>((ref) async {
  final repo = ref.watch(groupsRepositoryProvider);
  final groups = await repo.getGroups();
  if (groups.isEmpty) return BigInt.zero;
  final totals = await Future.wait<BigInt>(groups.map((g) async {
    try {
      final report = await repo.getMonthlyReport(groupId: g.id);
      return report.totalSpentCents;
    } catch (_) {
      return BigInt.zero;
    }
  }));
  var sum = BigInt.zero;
  for (final t in totals) {
    sum += t;
  }
  return sum;
});

class GroupsController extends StateNotifier<AsyncValue<List<GroupEntity>>> {
  final GroupsRepository repository;

  GroupsController({required this.repository, bool enabled = true})
      : super(enabled ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (enabled) load();
  }

  /// [silent] true: giữ danh sách đang hiện trong lúc tải lại (dùng khi số liệu thẻ, như quỹ chung, đổi từ màn khác).
  Future<void> load({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    try {
      final list = await repository.getGroups();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Lỗi được ném lại cho màn hình; thành công thì tải lại danh sách.
  Future<GroupEntity> create({
    required String name,
    GroupType type = GroupType.family,
    String? icon,
    String? description,
    String? settlementModel,
  }) async {
    final created = await repository.createGroup(name: name, type: type, icon: icon, description: description, settlementModel: settlementModel);
    await load();
    return created;
  }

  Future<void> delete(String id) async {
    await repository.deleteGroup(id);
    await load();
  }

  Future<void> leave(String id) async {
    await repository.leaveGroup(id);
    await load();
  }
}
