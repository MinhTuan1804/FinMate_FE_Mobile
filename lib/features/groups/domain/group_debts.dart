/// Hóa đơn chia, sổ nợ và duyệt khoản lớn của nhóm (Split bill). Tiền là số nguyên đồng.
library;

class GroupBillSplitEntity {
  final String userId;
  final String displayName;
  final BigInt shareCents;

  const GroupBillSplitEntity({required this.userId, required this.displayName, required this.shareCents});

  factory GroupBillSplitEntity.fromJson(Map<String, dynamic> json) => GroupBillSplitEntity(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? '',
        shareCents: BigInt.from((json['shareCents'] as num?) ?? 0),
      );
}

/// Hóa đơn đã chia. Không gắn ví, không tạo giao dịch cá nhân, không sửa hay xóa; toàn bộ số tiền tính vào chi tiêu nhóm, đứng tên người trả.
class GroupBillEntity {
  final String id;
  final String title;
  final BigInt amountCents;
  final String paidByUserId;
  final String paidByName;
  final DateTime occurredAt;

  /// 'Equal' | 'Custom'
  final String splitMode;
  final String? note;
  final int splitCount;
  final List<GroupBillSplitEntity> splits;

  const GroupBillEntity({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.paidByUserId,
    required this.paidByName,
    required this.occurredAt,
    required this.splitMode,
    this.note,
    required this.splitCount,
    this.splits = const [],
  });

  factory GroupBillEntity.fromJson(Map<String, dynamic> json) => GroupBillEntity(
        id: json['id'] as String,
        title: json['title'] as String,
        amountCents: BigInt.from(json['amountCents'] as num),
        paidByUserId: json['paidByUserId'] as String,
        paidByName: json['paidByName'] as String? ?? '',
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        splitMode: json['splitMode'] as String? ?? 'Equal',
        note: json['note'] as String?,
        splitCount: json['splitCount'] as int? ?? ((json['splits'] as List?)?.length ?? 0),
        splits: ((json['splits'] as List<dynamic>?) ?? const [])
            .map((e) => GroupBillSplitEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Một phần chia khi tạo hóa đơn. Với `Equal` server tự chia nên [shareCents] bị bỏ qua (gửi 0).
class GroupBillSplitInput {
  final String userId;
  final BigInt shareCents;
  const GroupBillSplitInput({required this.userId, required this.shareCents});

  Map<String, dynamic> toJson() => {'userId': userId, 'shareCents': shareCents.toInt()};
}

class GroupMemberBalanceEntity {
  final String userId;
  final String displayName;
  final bool isActive;

  /// DƯƠNG = đang được nợ (người khác nợ mình), ÂM = đang nợ. Tổng các thành viên bằng 0.
  final BigInt netCents;

  const GroupMemberBalanceEntity({required this.userId, required this.displayName, required this.isActive, required this.netCents});

  factory GroupMemberBalanceEntity.fromJson(Map<String, dynamic> json) => GroupMemberBalanceEntity(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        netCents: BigInt.from((json['netCents'] as num?) ?? 0),
      );
}

/// Một lượt chuyển tiền gợi ý để cấn trừ tối giản.
class GroupDebtTransferEntity {
  final String fromUserId;
  final String toUserId;
  final BigInt amountCents;

  const GroupDebtTransferEntity({required this.fromUserId, required this.toUserId, required this.amountCents});

  factory GroupDebtTransferEntity.fromJson(Map<String, dynamic> json) => GroupDebtTransferEntity(
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        amountCents: BigInt.from(json['amountCents'] as num),
      );
}

class GroupBalancesEntity {
  /// 'AiOptimized' | 'Manual'
  final String method;
  final List<GroupMemberBalanceEntity> members;

  /// null khi nhóm chọn cấn trừ Manual (không gợi ý lượt chuyển).
  final List<GroupDebtTransferEntity>? transfers;
  final BigInt? formerMembersNetCents;

  const GroupBalancesEntity({required this.method, required this.members, this.transfers, this.formerMembersNetCents});

  factory GroupBalancesEntity.fromJson(Map<String, dynamic> json) => GroupBalancesEntity(
        method: json['method'] as String? ?? 'AiOptimized',
        members: ((json['members'] as List<dynamic>?) ?? const [])
            .map((e) => GroupMemberBalanceEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        transfers: json['transfers'] == null
            ? null
            : (json['transfers'] as List<dynamic>).map((e) => GroupDebtTransferEntity.fromJson(e as Map<String, dynamic>)).toList(),
        formerMembersNetCents: json['formerMembersNetCents'] == null ? null : BigInt.from(json['formerMembersNetCents'] as num),
      );

  BigInt netOf(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m.netCents;
    }
    return BigInt.zero;
  }

  /// Các lượt chuyển liên quan tới [userId] (người trả hoặc người nhận).
  List<GroupDebtTransferEntity> transfersOf(String userId) =>
      (transfers ?? const <GroupDebtTransferEntity>[]).where((t) => t.fromUserId == userId || t.toUserId == userId).toList();
}

class GroupSettlementEntity {
  final String id;
  final String fromUserId;
  final String toUserId;
  final BigInt amountCents;
  final String? note;
  final DateTime createdAt;

  const GroupSettlementEntity({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    this.note,
    required this.createdAt,
  });

  factory GroupSettlementEntity.fromJson(Map<String, dynamic> json) => GroupSettlementEntity(
        id: json['id'] as String,
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        amountCents: BigInt.from(json['amountCents'] as num),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Kết quả nhắc nợ: `sent` đã gửi, `skipped` bị bỏ qua (quá giới hạn 1 lần/24 giờ hoặc không nợ).
class GroupReminderResult {
  final List<String> sent;
  final List<String> skipped;
  const GroupReminderResult({this.sent = const [], this.skipped = const []});

  factory GroupReminderResult.fromJson(Map<String, dynamic> json) => GroupReminderResult(
        sent: ((json['sent'] as List<dynamic>?) ?? const []).cast<String>(),
        skipped: ((json['skipped'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// Yêu cầu chờ duyệt (`kind` Bill hoặc FundEntry). KHÔNG phải hóa đơn hay dòng quỹ thật: khoản chờ chưa trừ quỹ,
/// chưa vào ngân sách, báo cáo hay sổ nợ cho tới khi chủ nhóm duyệt (lúc đó `resultId` trỏ tới khoản vừa tạo).
class GroupApprovalEntity {
  final String id;

  /// 'Bill' | 'FundEntry'
  final String kind;

  /// 'Pending' | 'Approved' | 'Rejected'
  final String status;
  final BigInt amountCents;
  final String title;
  final String requestedByUserId;
  final String requestedByName;
  final DateTime createdAt;
  final String? decisionReason;
  final String? resultId;

  const GroupApprovalEntity({
    required this.id,
    required this.kind,
    required this.status,
    required this.amountCents,
    required this.title,
    required this.requestedByUserId,
    required this.requestedByName,
    required this.createdAt,
    this.decisionReason,
    this.resultId,
  });

  bool get isPending => status == 'Pending';

  factory GroupApprovalEntity.fromJson(Map<String, dynamic> json) => GroupApprovalEntity(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? 'Bill',
        status: json['status'] as String? ?? 'Pending',
        amountCents: BigInt.from((json['amountCents'] as num?) ?? 0),
        title: json['title'] as String? ?? '',
        requestedByUserId: json['requestedByUserId'] as String? ?? '',
        requestedByName: json['requestedByName'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        decisionReason: json['decisionReason'] as String?,
        resultId: json['resultId'] as String?,
      );
}

/// Kết quả tạo hóa đơn: HTTP 201 là hóa đơn thật, HTTP 202 là yêu cầu chờ duyệt (khoản từ ngưỡng do người không phải chủ nhóm tạo).
/// App phải kiểm tra mã HTTP, không chỉ `success`.
class GroupBillCreateResult {
  final GroupBillEntity? bill;
  final GroupApprovalEntity? pending;
  const GroupBillCreateResult.created(GroupBillEntity this.bill) : pending = null;
  const GroupBillCreateResult.pending(GroupApprovalEntity this.pending) : bill = null;

  bool get isPending => pending != null;
}
