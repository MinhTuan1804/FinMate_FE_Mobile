import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';

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

class GroupsController extends StateNotifier<AsyncValue<List<GroupEntity>>> {
  final GroupsRepository repository;

  GroupsController({required this.repository, bool enabled = true})
      : super(enabled ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (enabled) load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await repository.getGroups();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Lỗi được ném lại cho màn hình; thành công thì tải lại danh sách.
  Future<GroupEntity> create({required String name, GroupType type = GroupType.family}) async {
    final created = await repository.createGroup(name: name, type: type);
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
