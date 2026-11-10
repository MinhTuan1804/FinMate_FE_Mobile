import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Loại nhóm.
enum GroupType {
  family('Family', 'Gia đình'),
  other('Other', 'Khác');

  final String apiValue;
  final String label;
  const GroupType(this.apiValue, this.label);

  static GroupType fromApi(String value) =>
      GroupType.values.firstWhere((t) => t.apiValue == value, orElse: () => GroupType.family);
}

/// Thứ tự khai báo là thứ bậc: owner có quyền lớn nhất.
enum GroupRole {
  owner('Owner', 'Chủ nhóm'),
  manager('Manager', 'Quản lý'),
  member('Member', 'Thành viên'),
  viewer('Viewer', 'Chỉ xem');

  final String apiValue;
  final String label;
  const GroupRole(this.apiValue, this.label);

  static GroupRole fromApi(String value) =>
      GroupRole.values.firstWhere((r) => r.apiValue == value, orElse: () => GroupRole.member);
}

/// Thành viên thường/chỉ xem thấy từng giao dịch (full) hay chỉ thấy tổng (summary).
enum GroupTransactionVisibility {
  full('Full', 'Xem từng giao dịch'),
  summary('Summary', 'Chỉ xem tổng');

  final String apiValue;
  final String label;
  const GroupTransactionVisibility(this.apiValue, this.label);

  static GroupTransactionVisibility fromApi(String value) => GroupTransactionVisibility.values
      .firstWhere((v) => v.apiValue == value, orElse: () => GroupTransactionVisibility.summary);
}

/// Quyền cấp thêm cho thành viên (không gồm các việc chỉ chủ nhóm mới làm được).
enum GroupPermission {
  viewOverview('ViewOverview', 'Xem tổng quan'),
  viewMemberTransactions('ViewMemberTransactions', 'Xem giao dịch của thành viên khác'),
  viewActivity('ViewActivity', 'Xem lịch sử hoạt động'),
  shareTransactions('ShareTransactions', 'Chia sẻ giao dịch'),
  contributeGoals('ContributeGoals', 'Góp tiền vào mục tiêu'),
  manageSharedTransactions('ManageSharedTransactions', 'Quản lý giao dịch đã chia sẻ'),
  manageBudgets('ManageBudgets', 'Quản lý ngân sách nhóm'),
  manageGoals('ManageGoals', 'Quản lý mục tiêu nhóm'),
  manageCategories('ManageCategories', 'Quản lý danh mục nhóm'),
  inviteMembers('InviteMembers', 'Mời thành viên'),
  removeMembers('RemoveMembers', 'Xóa thành viên');

  final String apiValue;
  final String label;
  const GroupPermission(this.apiValue, this.label);

  static GroupPermission? fromApi(String value) {
    for (final p in GroupPermission.values) {
      if (p.apiValue == value) return p;
    }
    return null;
  }
}

/// Loại hoạt động trong nhật ký nhóm.
enum GroupActivityType {
  groupCreated('GroupCreated', 'Tạo nhóm'),
  groupUpdated('GroupUpdated', 'Cập nhật nhóm'),
  memberJoined('MemberJoined', 'Thành viên tham gia'),
  memberLeft('MemberLeft', 'Thành viên rời nhóm'),
  memberRemoved('MemberRemoved', 'Thành viên bị xóa'),
  memberUpdated('MemberUpdated', 'Cập nhật thành viên'),
  ownershipTransferred('OwnershipTransferred', 'Chuyển quyền chủ nhóm'),
  invitationCreated('InvitationCreated', 'Tạo lời mời'),
  invitationRevoked('InvitationRevoked', 'Hủy lời mời'),
  transactionShared('TransactionShared', 'Chia sẻ giao dịch'),
  transactionUnshared('TransactionUnshared', 'Bỏ chia sẻ giao dịch'),
  transactionReclassified('TransactionReclassified', 'Đổi danh mục giao dịch'),
  budgetChanged('BudgetChanged', 'Thay đổi ngân sách'),
  goalChanged('GoalChanged', 'Thay đổi mục tiêu'),
  goalContributed('GoalContributed', 'Góp tiền vào mục tiêu'),
  categoryChanged('CategoryChanged', 'Thay đổi danh mục');

  final String apiValue;
  final String label;
  const GroupActivityType(this.apiValue, this.label);

  static GroupActivityType fromApi(String value) =>
      GroupActivityType.values.firstWhere((t) => t.apiValue == value, orElse: () => GroupActivityType.groupUpdated);
}

List<GroupPermission> _permissionsFromApi(List<dynamic>? values) {
  if (values == null) return const [];
  return values
      .map((v) => GroupPermission.fromApi(v as String))
      .whereType<GroupPermission>()
      .toList();
}

class GroupEntity {
  final String id;
  final String name;
  final GroupType type;
  final GroupTransactionVisibility transactionVisibility;
  final GroupRole myRole;
  final List<GroupPermission> myPermissions;
  final int memberCount;
  final DateTime createdAt;

  const GroupEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.transactionVisibility,
    required this.myRole,
    required this.myPermissions,
    required this.memberCount,
    required this.createdAt,
  });

  bool get isOwner => myRole == GroupRole.owner;

  factory GroupEntity.fromJson(Map<String, dynamic> json) => GroupEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        type: GroupType.fromApi(json['type'] as String),
        transactionVisibility: GroupTransactionVisibility.fromApi(json['transactionVisibility'] as String),
        myRole: GroupRole.fromApi(json['myRole'] as String),
        myPermissions: _permissionsFromApi(json['myPermissions'] as List<dynamic>?),
        memberCount: json['memberCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class GroupMemberEntity {
  final String userId;
  final String displayName;
  final bool isActive;
  final GroupRole role;
  final DateTime joinedAt;
  final List<GroupPermission>? permissions;
  final List<GroupPermission>? grantedPermissions;
  final List<GroupPermission>? revokedPermissions;

  const GroupMemberEntity({
    required this.userId,
    required this.displayName,
    required this.isActive,
    required this.role,
    required this.joinedAt,
    this.permissions,
    this.grantedPermissions,
    this.revokedPermissions,
  });

  factory GroupMemberEntity.fromJson(Map<String, dynamic> json) => GroupMemberEntity(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        isActive: json['isActive'] as bool,
        role: GroupRole.fromApi(json['role'] as String),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        permissions: json['permissions'] == null ? null : _permissionsFromApi(json['permissions'] as List<dynamic>?),
        grantedPermissions:
            json['grantedPermissions'] == null ? null : _permissionsFromApi(json['grantedPermissions'] as List<dynamic>?),
        revokedPermissions:
            json['revokedPermissions'] == null ? null : _permissionsFromApi(json['revokedPermissions'] as List<dynamic>?),
      );
}

class GroupActivityEntity {
  final String id;
  final GroupActivityType type;
  final String? actorUserId;
  final String? subjectId;
  final DateTime createdAt;

  const GroupActivityEntity({
    required this.id,
    required this.type,
    this.actorUserId,
    this.subjectId,
    required this.createdAt,
  });

  factory GroupActivityEntity.fromJson(Map<String, dynamic> json) => GroupActivityEntity(
        id: json['id'] as String,
        type: GroupActivityType.fromApi(json['type'] as String),
        actorUserId: json['actorUserId'] as String?,
        subjectId: json['subjectId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class GroupInvitationEntity {
  final String id;
  final String? email;
  final GroupRole role;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// Chỉ có đúng một lần lúc tạo lời mời qua link (không gửi email); DB chỉ giữ hash nên không xem lại được.
  final String? token;

  /// Với lời mời qua email: nhà cung cấp email có nhận thư không.
  final bool? emailSent;

  const GroupInvitationEntity({
    required this.id,
    this.email,
    required this.role,
    required this.expiresAt,
    required this.createdAt,
    this.token,
    this.emailSent,
  });

  factory GroupInvitationEntity.fromJson(Map<String, dynamic> json) => GroupInvitationEntity(
        id: json['id'] as String,
        email: json['email'] as String?,
        role: GroupRole.fromApi(json['role'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        token: json['token'] as String?,
        emailSent: json['emailSent'] as bool?,
      );
}

class GroupInvitationPreviewEntity {
  final String groupName;
  final GroupType groupType;
  final GroupRole role;
  final String? invitedBy;
  final DateTime expiresAt;

  const GroupInvitationPreviewEntity({
    required this.groupName,
    required this.groupType,
    required this.role,
    this.invitedBy,
    required this.expiresAt,
  });

  factory GroupInvitationPreviewEntity.fromJson(Map<String, dynamic> json) => GroupInvitationPreviewEntity(
        groupName: json['groupName'] as String,
        groupType: GroupType.fromApi(json['groupType'] as String),
        role: GroupRole.fromApi(json['role'] as String),
        invitedBy: json['invitedBy'] as String?,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class GroupCategoryEntity {
  final String id;
  final String name;
  final String slug;
  final String? iconName;

  const GroupCategoryEntity({required this.id, required this.name, required this.slug, this.iconName});

  factory GroupCategoryEntity.fromJson(Map<String, dynamic> json) => GroupCategoryEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        iconName: json['iconName'] as String?,
      );
}

/// Một giao dịch đã chia sẻ vào nhóm (GET /groups/{id}/transactions).
class GroupTransactionEntity {
  final String id;
  final String memberUserId;
  final String memberName;
  final BigInt amountCents;
  final TransactionType transactionType;
  final String? merchantName;
  final String? description;
  final DateTime transactedAt;
  final DateTime? sharedAt;
  final String? groupCategoryId;
  final String categoryName;

  const GroupTransactionEntity({
    required this.id,
    required this.memberUserId,
    required this.memberName,
    required this.amountCents,
    required this.transactionType,
    this.merchantName,
    this.description,
    required this.transactedAt,
    this.sharedAt,
    this.groupCategoryId,
    required this.categoryName,
  });

  factory GroupTransactionEntity.fromJson(Map<String, dynamic> json) => GroupTransactionEntity(
        id: json['id'] as String,
        memberUserId: json['memberUserId'] as String,
        memberName: json['memberName'] as String,
        amountCents: parseCents(json['amountCents']),
        transactionType: TransactionType.fromApi(json['transactionType'] as String?),
        merchantName: json['merchantName'] as String?,
        description: json['description'] as String?,
        transactedAt: DateTime.parse(json['transactedAt'] as String).toLocal(),
        sharedAt: (json['sharedAt'] as String?) == null ? null : DateTime.parse(json['sharedAt'] as String).toLocal(),
        groupCategoryId: json['groupCategoryId'] as String?,
        categoryName: json['categoryName'] as String,
      );

  String get formattedAmount => formatVnd(amountCents);
}

/// Tổng chi theo một danh mục (trong [GroupMonthlyReportEntity.byCategory]).
class GroupCategorySpendEntity {
  final String? categoryId;
  final String? groupCategoryId;
  final String categoryName;
  final BigInt spentCents;

  const GroupCategorySpendEntity({this.categoryId, this.groupCategoryId, required this.categoryName, required this.spentCents});

  factory GroupCategorySpendEntity.fromJson(Map<String, dynamic> json) => GroupCategorySpendEntity(
        categoryId: json['categoryId'] as String?,
        groupCategoryId: json['groupCategoryId'] as String?,
        categoryName: json['categoryName'] as String,
        spentCents: parseCents(json['spentCents']),
      );

  String get formattedSpent => formatVnd(spentCents);
}

/// Tổng thu chi của một thành viên (trong [GroupMonthlyReportEntity.byMember]).
class GroupMemberTotalsEntity {
  final String userId;
  final String memberName;
  final BigInt spentCents;
  final BigInt incomeCents;

  const GroupMemberTotalsEntity({required this.userId, required this.memberName, required this.spentCents, required this.incomeCents});

  factory GroupMemberTotalsEntity.fromJson(Map<String, dynamic> json) => GroupMemberTotalsEntity(
        userId: json['userId'] as String,
        memberName: json['memberName'] as String,
        spentCents: parseCents(json['spentCents']),
        incomeCents: parseCents(json['incomeCents']),
      );

  String get formattedSpent => formatVnd(spentCents);
  String get formattedIncome => formatVnd(incomeCents);
}

/// Báo cáo tổng thu chi một tháng của nhóm (GET /groups/{id}/reports/monthly).
class GroupMonthlyReportEntity {
  final int year;
  final int month;
  final BigInt totalSpentCents;
  final BigInt totalIncomeCents;
  final List<GroupCategorySpendEntity> byCategory;
  final List<GroupMemberTotalsEntity> byMember;

  const GroupMonthlyReportEntity({
    required this.year,
    required this.month,
    required this.totalSpentCents,
    required this.totalIncomeCents,
    required this.byCategory,
    required this.byMember,
  });

  factory GroupMonthlyReportEntity.fromJson(Map<String, dynamic> json) => GroupMonthlyReportEntity(
        year: json['year'] as int,
        month: json['month'] as int,
        totalSpentCents: parseCents(json['totalSpentCents']),
        totalIncomeCents: parseCents(json['totalIncomeCents']),
        byCategory: (json['byCategory'] as List<dynamic>? ?? const [])
            .map((e) => GroupCategorySpendEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        byMember: (json['byMember'] as List<dynamic>? ?? const [])
            .map((e) => GroupMemberTotalsEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get formattedTotalSpent => formatVnd(totalSpentCents);
  String get formattedTotalIncome => formatVnd(totalIncomeCents);
}

/// Quy tắc tự chia sẻ giao dịch vào nhóm theo tài khoản và/hoặc danh mục của chính mình
/// (GET/POST/DELETE /groups/{id}/share-rules).
class GroupShareRuleEntity {
  final String id;
  final String? financialAccountId;
  final String? categoryId;
  final DateTime createdAt;

  const GroupShareRuleEntity({
    required this.id,
    this.financialAccountId,
    this.categoryId,
    required this.createdAt,
  });

  factory GroupShareRuleEntity.fromJson(Map<String, dynamic> json) => GroupShareRuleEntity(
        id: json['id'] as String,
        financialAccountId: json['financialAccountId'] as String?,
        categoryId: json['categoryId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

enum GroupBudgetStatusLevel { safe, warning, danger }

/// Ngân sách của nhóm: cả [categoryId] và [groupCategoryId] đều null là ngân sách tổng của nhóm
/// (GET/POST/PATCH/DELETE /groups/{id}/budgets).
class GroupBudgetEntity {
  final String id;
  final String? categoryId;
  final String? groupCategoryId;
  final String? categoryName;
  final BigInt limitCents;
  final BigInt spentCents;
  final BigInt remainingCents;
  final int percentUsed;
  final bool isOverLimit;

  const GroupBudgetEntity({
    required this.id,
    this.categoryId,
    this.groupCategoryId,
    this.categoryName,
    required this.limitCents,
    required this.spentCents,
    required this.remainingCents,
    required this.percentUsed,
    required this.isOverLimit,
  });

  bool get isTotal => categoryId == null && groupCategoryId == null;

  GroupBudgetStatusLevel get statusLevel {
    if (isOverLimit || percentUsed >= 90) return GroupBudgetStatusLevel.danger;
    if (percentUsed >= 70) return GroupBudgetStatusLevel.warning;
    return GroupBudgetStatusLevel.safe;
  }

  factory GroupBudgetEntity.fromJson(Map<String, dynamic> json) => GroupBudgetEntity(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String?,
        groupCategoryId: json['groupCategoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        limitCents: parseCents(json['limitCents']),
        spentCents: parseCents(json['spentCents']),
        remainingCents: parseCents(json['remainingCents']),
        percentUsed: json['percentUsed'] as int,
        isOverLimit: json['isOverLimit'] as bool,
      );

  String get formattedLimit => formatVnd(limitCents);
  String get formattedSpent => formatVnd(spentCents);
  String get formattedRemaining => formatVnd(remainingCents);
}

/// Một lần góp tiền vào mục tiêu nhóm, có kèm người góp (khác mục tiêu cá nhân chỉ có một người góp)
/// (GET /groups/{id}/goals/{goalId}/contributions).
class GroupContributionEntity {
  final String id;
  final String memberUserId;
  final String memberName;
  final BigInt amountCents;
  final String? note;
  final DateTime contributedAt;

  const GroupContributionEntity({
    required this.id,
    required this.memberUserId,
    required this.memberName,
    required this.amountCents,
    this.note,
    required this.contributedAt,
  });

  factory GroupContributionEntity.fromJson(Map<String, dynamic> json) => GroupContributionEntity(
        id: json['id'] as String,
        memberUserId: json['memberUserId'] as String,
        memberName: json['memberName'] as String,
        amountCents: parseCents(json['amountCents']),
        note: json['note'] as String?,
        contributedAt: DateTime.parse(json['contributedAt'] as String).toLocal(),
      );

  String get formattedAmount => formatVnd(amountCents);
}
