import 'package:finmate/core/format/money.dart';

/// Loại dòng trong sổ quỹ chung (Phase 85).
enum GroupFundEntryKind {
  contribution('Contribution', 'Góp quỹ'),
  expense('Expense', 'Chi từ quỹ'),
  withdrawal('Withdrawal', 'Rút quỹ'),
  adjustment('Adjustment', 'Điều chỉnh');

  final String apiValue;
  final String label;
  const GroupFundEntryKind(this.apiValue, this.label);

  static GroupFundEntryKind fromApi(String value) =>
      GroupFundEntryKind.values.firstWhere((k) => k.apiValue == value, orElse: () => GroupFundEntryKind.adjustment);
}

/// Quỹ chung ảo của nhóm (GET /groups/{id}/funds) — FinMate không giữ tiền, chỉ ghi sổ.
class GroupFundEntity {
  final String id;
  final String name;
  final String? note;
  final BigInt balanceCents;
  final bool isNegative;
  final bool isArchived;
  final DateTime? archivedAt;

  const GroupFundEntity({
    required this.id,
    required this.name,
    this.note,
    required this.balanceCents,
    required this.isNegative,
    required this.isArchived,
    this.archivedAt,
  });

  String get formattedBalance => formatVnd(balanceCents);

  factory GroupFundEntity.fromJson(Map<String, dynamic> json) => GroupFundEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        note: json['note'] as String?,
        balanceCents: parseCents(json['balanceCents']),
        isNegative: json['isNegative'] as bool? ?? false,
        isArchived: json['isArchived'] as bool? ?? false,
        archivedAt: (json['archivedAt'] as String?) == null ? null : DateTime.parse(json['archivedAt'] as String).toLocal(),
      );
}

/// Tổng góp/rút của một thành viên trong kỳ (trong [GroupFundSummaryEntity]).
class GroupFundMemberAmountEntity {
  final String userId;
  final String memberName;
  final BigInt amountCents;

  const GroupFundMemberAmountEntity({required this.userId, required this.memberName, required this.amountCents});

  String get formattedAmount => formatVnd(amountCents);

  factory GroupFundMemberAmountEntity.fromJson(Map<String, dynamic> json) => GroupFundMemberAmountEntity(
        userId: json['userId'] as String,
        memberName: json['memberName'] as String,
        amountCents: parseCents(json['amountCents']),
      );
}

/// Tổng chi theo danh mục trong kỳ (trong [GroupFundSummaryEntity]).
class GroupFundCategorySpendEntity {
  final String? categoryId;
  final String? groupCategoryId;
  final String categoryName;
  final BigInt spentCents;

  const GroupFundCategorySpendEntity({this.categoryId, this.groupCategoryId, required this.categoryName, required this.spentCents});

  String get formattedSpent => formatVnd(spentCents);

  factory GroupFundCategorySpendEntity.fromJson(Map<String, dynamic> json) => GroupFundCategorySpendEntity(
        categoryId: json['categoryId'] as String?,
        groupCategoryId: json['groupCategoryId'] as String?,
        categoryName: json['categoryName'] as String,
        spentCents: parseCents(json['spentCents']),
      );
}

/// Tổng kết một quỹ trong tháng (GET /funds/{fundId}/summary).
class GroupFundSummaryEntity {
  final BigInt openingCents;
  final BigInt contributedCents;
  final List<GroupFundMemberAmountEntity> contributionsByMember;
  final BigInt spentCents;
  final List<GroupFundCategorySpendEntity> expensesByCategory;
  final BigInt withdrawnCents;
  final List<GroupFundMemberAmountEntity> withdrawalsByMember;
  final BigInt adjustmentsCents;
  final BigInt closingCents;

  const GroupFundSummaryEntity({
    required this.openingCents,
    required this.contributedCents,
    required this.contributionsByMember,
    required this.spentCents,
    required this.expensesByCategory,
    required this.withdrawnCents,
    required this.withdrawalsByMember,
    required this.adjustmentsCents,
    required this.closingCents,
  });

  factory GroupFundSummaryEntity.fromJson(Map<String, dynamic> json) => GroupFundSummaryEntity(
        openingCents: parseCents(json['openingCents']),
        contributedCents: parseCents(json['contributedCents']),
        contributionsByMember: (json['contributionsByMember'] as List<dynamic>? ?? const [])
            .map((e) => GroupFundMemberAmountEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        spentCents: parseCents(json['spentCents']),
        expensesByCategory: (json['expensesByCategory'] as List<dynamic>? ?? const [])
            .map((e) => GroupFundCategorySpendEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        withdrawnCents: parseCents(json['withdrawnCents']),
        withdrawalsByMember: (json['withdrawalsByMember'] as List<dynamic>? ?? const [])
            .map((e) => GroupFundMemberAmountEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        adjustmentsCents: parseCents(json['adjustmentsCents']),
        closingCents: parseCents(json['closingCents']),
      );
}

/// Một dòng trong sổ quỹ (GET /funds/{fundId}/entries).
class GroupFundEntryEntity {
  final String id;
  final GroupFundEntryKind kind;
  final BigInt amountCents;
  final DateTime transactedAt;
  final String memberUserId;
  final String memberName;
  final String? categoryId;
  final String? groupCategoryId;
  final String? categoryName;
  final String? note;
  final String? merchantName;

  const GroupFundEntryEntity({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.transactedAt,
    required this.memberUserId,
    required this.memberName,
    this.categoryId,
    this.groupCategoryId,
    this.categoryName,
    this.note,
    this.merchantName,
  });

  String get formattedAmount => formatVnd(amountCents);

  /// Dương (góp quỹ) hay âm (chi/rút quỹ) khi hiển thị trong sổ quỹ.
  bool get isCredit => kind == GroupFundEntryKind.contribution || (kind == GroupFundEntryKind.adjustment && amountCents > BigInt.zero);

  factory GroupFundEntryEntity.fromJson(Map<String, dynamic> json) => GroupFundEntryEntity(
        id: json['id'] as String,
        kind: GroupFundEntryKind.fromApi(json['kind'] as String),
        amountCents: parseCents(json['amountCents']),
        transactedAt: DateTime.parse(json['transactedAt'] as String).toLocal(),
        memberUserId: json['memberUserId'] as String,
        memberName: json['memberName'] as String,
        categoryId: json['categoryId'] as String?,
        groupCategoryId: json['groupCategoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        note: json['note'] as String?,
        merchantName: json['merchantName'] as String?,
      );
}
