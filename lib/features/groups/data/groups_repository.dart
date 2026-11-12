import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(apiClient: ref.watch(apiClientProvider)),
);

class GroupsRepository {
  final ApiClient apiClient;
  GroupsRepository({required this.apiClient});

  Future<List<GroupEntity>> getGroups() async {
    final res = await apiClient.get<List<GroupEntity>>(
      '/api/v1/groups',
      fromJsonT: (json) => (json as List).map((e) => GroupEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  Future<GroupEntity> getGroup(String id) async {
    final res = await apiClient.get<GroupEntity>(
      '/api/v1/groups/$id',
      fromJsonT: (json) => GroupEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupEntity;
  }

  Future<GroupEntity> createGroup({required String name, GroupType type = GroupType.family}) async {
    final res = await apiClient.post<GroupEntity>(
      '/api/v1/groups',
      data: {'name': name, 'type': type.apiValue},
      fromJsonT: (json) => GroupEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupEntity;
  }

  /// [name]/[transactionVisibility] null = giữ nguyên.
  Future<GroupEntity> updateGroup({
    required String id,
    String? name,
    GroupTransactionVisibility? transactionVisibility,
  }) async {
    final res = await apiClient.patch<GroupEntity>(
      '/api/v1/groups/$id',
      data: {
        if (name != null) 'name': name,
        if (transactionVisibility != null) 'transactionVisibility': transactionVisibility.apiValue,
      },
      fromJsonT: (json) => GroupEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupEntity;
  }

  Future<void> deleteGroup(String id) => apiClient.delete('/api/v1/groups/$id');

  Future<List<GroupActivityEntity>> getActivities(String id, {int limit = 50}) async {
    final res = await apiClient.get<List<GroupActivityEntity>>(
      '/api/v1/groups/$id/activities',
      queryParameters: {'limit': limit},
      fromJsonT: (json) => (json as List).map((e) => GroupActivityEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  Future<List<GroupMemberEntity>> getMembers(String id) async {
    final res = await apiClient.get<List<GroupMemberEntity>>(
      '/api/v1/groups/$id/members',
      fromJsonT: (json) => (json as List).map((e) => GroupMemberEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  /// [role] null = giữ nguyên vai trò hiện tại.
  Future<GroupMemberEntity> updateMember({
    required String groupId,
    required String userId,
    GroupRole? role,
    List<GroupPermission>? grantedPermissions,
    List<GroupPermission>? revokedPermissions,
  }) async {
    final res = await apiClient.patch<GroupMemberEntity>(
      '/api/v1/groups/$groupId/members/$userId',
      data: {
        if (role != null) 'role': role.apiValue,
        if (grantedPermissions != null) 'grantedPermissions': grantedPermissions.map((p) => p.apiValue).toList(),
        if (revokedPermissions != null) 'revokedPermissions': revokedPermissions.map((p) => p.apiValue).toList(),
      },
      fromJsonT: (json) => GroupMemberEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupMemberEntity;
  }

  Future<void> removeMember({required String groupId, required String userId}) =>
      apiClient.delete('/api/v1/groups/$groupId/members/$userId');

  Future<void> setAlerts({required String groupId, required bool enabled}) async {
    await apiClient.put<void>(
      '/api/v1/groups/$groupId/alerts',
      data: {'enabled': enabled},
      fromJsonT: (_) {},
    );
  }

  Future<void> leaveGroup(String groupId) async {
    await apiClient.post<void>('/api/v1/groups/$groupId/leave', fromJsonT: (_) {});
  }

  Future<void> transferOwnership({required String groupId, required String newOwnerUserId}) async {
    await apiClient.post<void>(
      '/api/v1/groups/$groupId/transfer-ownership',
      data: {'newOwnerUserId': newOwnerUserId},
      fromJsonT: (_) {},
    );
  }

  /// [email] null = tạo lời mời qua link (không gửi email); kết quả trả [GroupInvitationEntity.token] đúng một lần.
  Future<GroupInvitationEntity> createInvitation({
    required String groupId,
    String? email,
    GroupRole role = GroupRole.member,
  }) async {
    final res = await apiClient.post<GroupInvitationEntity>(
      '/api/v1/groups/$groupId/invitations',
      data: {if (email != null && email.isNotEmpty) 'email': email, 'role': role.apiValue},
      fromJsonT: (json) => GroupInvitationEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupInvitationEntity;
  }

  Future<List<GroupInvitationEntity>> getInvitations(String groupId) async {
    final res = await apiClient.get<List<GroupInvitationEntity>>(
      '/api/v1/groups/$groupId/invitations',
      fromJsonT: (json) => (json as List).map((e) => GroupInvitationEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  Future<void> revokeInvitation({required String groupId, required String invitationId}) =>
      apiClient.delete('/api/v1/groups/$groupId/invitations/$invitationId');

  /// Giao dịch đã chia sẻ vào nhóm trong một tháng (giờ Việt Nam); [year]/[month] null = tháng này (BE tự chọn).
  Future<List<GroupTransactionEntity>> getTransactions({required String groupId, int? year, int? month, int limit = 100}) async {
    final res = await apiClient.get<List<GroupTransactionEntity>>(
      '/api/v1/groups/$groupId/transactions',
      queryParameters: {
        if (year != null) 'year': year,
        if (month != null) 'month': month,
        'limit': limit,
      },
      fromJsonT: (json) => (json as List).map((e) => GroupTransactionEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  /// [groupCategoryId] null = bỏ phân loại (không phải "giữ nguyên" như các hàm update khác).
  Future<void> reclassifyTransaction({required String groupId, required String transactionId, String? groupCategoryId}) async {
    await apiClient.patch<void>(
      '/api/v1/groups/$groupId/transactions/$transactionId',
      data: {'groupCategoryId': groupCategoryId},
      fromJsonT: (_) {},
    );
  }

  Future<void> removeTransaction({required String groupId, required String transactionId}) =>
      apiClient.delete('/api/v1/groups/$groupId/transactions/$transactionId');

  /// Tổng thu chi một tháng (giờ Việt Nam) theo danh mục và theo thành viên; [year]/[month] null = tháng này.
  Future<GroupMonthlyReportEntity> getMonthlyReport({required String groupId, int? year, int? month}) async {
    final res = await apiClient.get<GroupMonthlyReportEntity>(
      '/api/v1/groups/$groupId/reports/monthly',
      queryParameters: {
        if (year != null) 'year': year,
        if (month != null) 'month': month,
      },
      fromJsonT: (json) => GroupMonthlyReportEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupMonthlyReportEntity;
  }

  Future<List<GroupCategoryEntity>> getCategories(String groupId) async {
    final res = await apiClient.get<List<GroupCategoryEntity>>(
      '/api/v1/groups/$groupId/categories',
      fromJsonT: (json) => (json as List).map((e) => GroupCategoryEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  Future<GroupCategoryEntity> createCategory({required String groupId, required String name, String? iconName}) async {
    final res = await apiClient.post<GroupCategoryEntity>(
      '/api/v1/groups/$groupId/categories',
      data: {'name': name, if (iconName != null) 'iconName': iconName},
      fromJsonT: (json) => GroupCategoryEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupCategoryEntity;
  }

  Future<void> deleteCategory({required String groupId, required String categoryId}) =>
      apiClient.delete('/api/v1/groups/$groupId/categories/$categoryId');

  Future<List<GroupShareRuleEntity>> getShareRules(String groupId) async {
    final res = await apiClient.get<List<GroupShareRuleEntity>>(
      '/api/v1/groups/$groupId/share-rules',
      fromJsonT: (json) => (json as List).map((e) => GroupShareRuleEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  /// Chỉ nên đặt đúng một trong hai: theo tài khoản hoặc theo danh mục của chính mình.
  Future<GroupShareRuleEntity> createShareRule({
    required String groupId,
    String? financialAccountId,
    String? categoryId,
  }) async {
    final res = await apiClient.post<GroupShareRuleEntity>(
      '/api/v1/groups/$groupId/share-rules',
      data: {'financialAccountId': financialAccountId, 'categoryId': categoryId},
      fromJsonT: (json) => GroupShareRuleEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupShareRuleEntity;
  }

  Future<void> deleteShareRule({required String groupId, required String ruleId}) =>
      apiClient.delete('/api/v1/groups/$groupId/share-rules/$ruleId');

  Future<List<GroupBudgetEntity>> getBudgets(String groupId) async {
    final res = await apiClient.get<List<GroupBudgetEntity>>(
      '/api/v1/groups/$groupId/budgets',
      fromJsonT: (json) => (json as List).map((e) => GroupBudgetEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  /// [categoryId]/[groupCategoryId] cùng để trống = ngân sách tổng của nhóm.
  Future<GroupBudgetEntity> createBudget({
    required String groupId,
    String? categoryId,
    String? groupCategoryId,
    required BigInt limitCents,
  }) async {
    final res = await apiClient.post<GroupBudgetEntity>(
      '/api/v1/groups/$groupId/budgets',
      data: {'categoryId': categoryId, 'groupCategoryId': groupCategoryId, 'limitCents': limitCents.toInt()},
      fromJsonT: (json) => GroupBudgetEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupBudgetEntity;
  }

  Future<GroupBudgetEntity> updateBudgetLimit({
    required String groupId,
    required String budgetId,
    required BigInt limitCents,
  }) async {
    final res = await apiClient.patch<GroupBudgetEntity>(
      '/api/v1/groups/$groupId/budgets/$budgetId',
      data: {'limitCents': limitCents.toInt()},
      fromJsonT: (json) => GroupBudgetEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupBudgetEntity;
  }

  Future<void> deleteBudget({required String groupId, required String budgetId}) =>
      apiClient.delete('/api/v1/groups/$groupId/budgets/$budgetId');

  /// Mục tiêu nhóm dùng lại đúng DTO của mục tiêu cá nhân ([SavingsGoalEntity]) ở phía BE.
  Future<List<SavingsGoalEntity>> getGoals(String groupId) async {
    final res = await apiClient.get<List<SavingsGoalEntity>>(
      '/api/v1/groups/$groupId/goals',
      fromJsonT: (json) => (json as List).map((e) => SavingsGoalEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  Future<SavingsGoalEntity> createGoal({
    required String groupId,
    required String name,
    required BigInt targetCents,
    DateTime? deadline,
  }) async {
    final res = await apiClient.post<SavingsGoalEntity>(
      '/api/v1/groups/$groupId/goals',
      data: {
        'name': name,
        'targetCents': targetCents.toInt(),
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
      },
      fromJsonT: (json) => SavingsGoalEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SavingsGoalEntity;
  }

  /// Mọi trường null = giữ nguyên.
  Future<SavingsGoalEntity> updateGoal({
    required String groupId,
    required String goalId,
    String? name,
    BigInt? targetCents,
    DateTime? deadline,
  }) async {
    final res = await apiClient.patch<SavingsGoalEntity>(
      '/api/v1/groups/$groupId/goals/$goalId',
      data: {
        if (name != null) 'name': name,
        if (targetCents != null) 'targetCents': targetCents.toInt(),
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
      },
      fromJsonT: (json) => SavingsGoalEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SavingsGoalEntity;
  }

  Future<void> cancelGoal({required String groupId, required String goalId}) async {
    await apiClient.post<void>('/api/v1/groups/$groupId/goals/$goalId/cancel', fromJsonT: (_) {});
  }

  Future<SavingsGoalEntity> contributeToGoal({
    required String groupId,
    required String goalId,
    required BigInt amountCents,
    String? note,
  }) async {
    final res = await apiClient.post<SavingsGoalEntity>(
      '/api/v1/groups/$groupId/goals/$goalId/contribute',
      data: {'amountCents': amountCents.toInt(), if (note != null && note.isNotEmpty) 'note': note},
      fromJsonT: (json) => SavingsGoalEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SavingsGoalEntity;
  }

  Future<List<GroupContributionEntity>> getGoalContributions({
    required String groupId,
    required String goalId,
    int limit = 50,
  }) async {
    final res = await apiClient.get<List<GroupContributionEntity>>(
      '/api/v1/groups/$groupId/goals/$goalId/contributions',
      queryParameters: {'limit': limit},
      fromJsonT: (json) => (json as List).map((e) => GroupContributionEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }
}
