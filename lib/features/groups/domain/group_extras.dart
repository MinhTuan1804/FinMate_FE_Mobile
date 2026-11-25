/// Cài đặt nhóm (`GET/PUT /groups/{id}/settings`). PUT thay toàn bộ nên luôn gửi đủ các trường.
class GroupSettingsEntity {
  /// null = cuối tháng.
  final int? closingDay;

  /// 'AiOptimized' | 'Manual'
  final String debtSettlementMethod;

  /// Khoản từ ngưỡng này trở lên do người không phải chủ nhóm tạo sẽ chờ duyệt; null = tắt.
  final BigInt? requireApprovalAboveCents;
  final bool notifyOnNewTransaction;
  final bool weeklySummary;

  /// 1 = thứ Hai … 7 = Chủ nhật.
  final int weeklySummaryDay;

  /// "HH:mm" giờ Việt Nam.
  final String weeklySummaryTime;

  /// Chỉ đọc — đổi bằng `PUT /groups/{id}/alerts`.
  final bool alertsEnabled;

  const GroupSettingsEntity({
    this.closingDay,
    this.debtSettlementMethod = 'AiOptimized',
    this.requireApprovalAboveCents,
    this.notifyOnNewTransaction = true,
    this.weeklySummary = false,
    this.weeklySummaryDay = 1,
    this.weeklySummaryTime = '09:00',
    this.alertsEnabled = true,
  });

  factory GroupSettingsEntity.fromJson(Map<String, dynamic> json) => GroupSettingsEntity(
        closingDay: json['closingDay'] as int?,
        debtSettlementMethod: json['debtSettlementMethod'] as String? ?? 'AiOptimized',
        requireApprovalAboveCents:
            json['requireApprovalAboveCents'] == null ? null : BigInt.from(json['requireApprovalAboveCents'] as num),
        notifyOnNewTransaction: json['notifyOnNewTransaction'] as bool? ?? true,
        weeklySummary: json['weeklySummary'] as bool? ?? false,
        weeklySummaryDay: json['weeklySummaryDay'] as int? ?? 1,
        weeklySummaryTime: json['weeklySummaryTime'] as String? ?? '09:00',
        alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      );

  GroupSettingsEntity copyWith({
    int? closingDay,
    bool clearClosingDay = false,
    String? debtSettlementMethod,
    BigInt? requireApprovalAboveCents,
    bool clearApproval = false,
    bool? notifyOnNewTransaction,
    bool? weeklySummary,
    int? weeklySummaryDay,
    String? weeklySummaryTime,
  }) =>
      GroupSettingsEntity(
        closingDay: clearClosingDay ? null : (closingDay ?? this.closingDay),
        debtSettlementMethod: debtSettlementMethod ?? this.debtSettlementMethod,
        requireApprovalAboveCents: clearApproval ? null : (requireApprovalAboveCents ?? this.requireApprovalAboveCents),
        notifyOnNewTransaction: notifyOnNewTransaction ?? this.notifyOnNewTransaction,
        weeklySummary: weeklySummary ?? this.weeklySummary,
        weeklySummaryDay: weeklySummaryDay ?? this.weeklySummaryDay,
        weeklySummaryTime: weeklySummaryTime ?? this.weeklySummaryTime,
        alertsEnabled: alertsEnabled,
      );

  /// Thân PUT: thay toàn bộ, không gồm `alertsEnabled` (chỉ đọc).
  Map<String, dynamic> toJson() => {
        'closingDay': closingDay,
        'debtSettlementMethod': debtSettlementMethod,
        'requireApprovalAboveCents': requireApprovalAboveCents?.toInt(),
        'notifyOnNewTransaction': notifyOnNewTransaction,
        'weeklySummary': weeklySummary,
        'weeklySummaryDay': weeklySummaryDay,
        'weeklySummaryTime': weeklySummaryTime,
      };
}

/// Một kết quả tìm người để mời (`GET /users/search`). Chỉ khớp chính xác email đã xác minh hoặc FinMate ID.
class UserSearchResult {
  final String userId;
  final String displayName;
  final String? maskedEmail;
  final String? finMateId;

  const UserSearchResult({
    required this.userId,
    required this.displayName,
    this.maskedEmail,
    this.finMateId,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) => UserSearchResult(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        maskedEmail: json['maskedEmail'] as String?,
        finMateId: json['finMateId'] as String?,
      );
}

/// Gợi ý người cùng nhóm khác, chưa ở nhóm này (`GET /groups/{id}/invite-suggestions`).
class InviteSuggestion {
  final String userId;
  final String displayName;
  final String? finMateId;
  final int sharedGroupCount;

  const InviteSuggestion({required this.userId, required this.displayName, this.finMateId, this.sharedGroupCount = 0});

  factory InviteSuggestion.fromJson(Map<String, dynamic> json) => InviteSuggestion(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        finMateId: json['finMateId'] as String?,
        sharedGroupCount: json['sharedGroupCount'] as int? ?? 0,
      );
}

/// Tổng quan của tôi trên danh sách nhóm (`GET /groups/me/summary`).
class GroupsSummaryEntity {
  final BigInt totalSpentCents;
  final int activeGroupCount;

  /// Tổng phần của MÌNH trong hóa đơn của tháng; null nếu chưa nhóm nào có hóa đơn.
  final BigInt? myShareDueCents;

  /// Tổng số mình đang nợ lúc này (cộng dồn); null nếu chưa nhóm nào có hóa đơn hoặc trả nợ.
  final BigInt? myPayableCents;

  /// Ngày chốt sổ gần nhất sắp tới.
  final DateTime? closingDate;

  const GroupsSummaryEntity({
    required this.totalSpentCents,
    required this.activeGroupCount,
    this.myShareDueCents,
    this.myPayableCents,
    this.closingDate,
  });

  factory GroupsSummaryEntity.fromJson(Map<String, dynamic> json) => GroupsSummaryEntity(
        totalSpentCents: BigInt.from((json['totalSpentCents'] as num?) ?? 0),
        activeGroupCount: json['activeGroupCount'] as int? ?? 0,
        myShareDueCents: json['myShareDueCents'] == null ? null : BigInt.from(json['myShareDueCents'] as num),
        myPayableCents: json['myPayableCents'] == null ? null : BigInt.from(json['myPayableCents'] as num),
        closingDate: json['closingDate'] == null ? null : DateTime.parse(json['closingDate'] as String),
      );
}
