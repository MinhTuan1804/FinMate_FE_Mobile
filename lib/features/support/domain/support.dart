/// [category]: nguyên văn tên enum BE (PascalCase, không qua bộ chuyển đổi lowercase nào) —
/// 'Security' | 'Account' | 'Transaction' | 'Receipt' | 'Notification' | 'Group' | 'Question'.
/// [status]: 'New' | 'InProgress' | 'WaitingCustomer' | 'Escalated' | 'Resolved' | 'Closed'.
/// Không có trường Priority: BE không lộ mức ưu tiên cho khách (khách không tự chọn được).
class SupportTicketEntity {
  final String id;
  final String category;
  final String status;
  final String subject;
  final int? rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  const SupportTicketEntity({
    required this.id,
    required this.category,
    required this.status,
    required this.subject,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.closedAt,
  });

  bool get isClosed => status == 'Closed';
  bool get canRate => status == 'Resolved' || status == 'Closed';

  factory SupportTicketEntity.fromJson(Map<String, dynamic> json) => SupportTicketEntity(
        id: json['id'] as String,
        category: json['category'] as String,
        status: json['status'] as String,
        subject: json['subject'] as String,
        rating: json['rating'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String).toLocal(),
        closedAt: json['closedAt'] == null ? null : DateTime.parse(json['closedAt'] as String).toLocal(),
      );
}

class SupportAttachmentEntity {
  final String id;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;

  const SupportAttachmentEntity({
    required this.id,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory SupportAttachmentEntity.fromJson(Map<String, dynamic> json) => SupportAttachmentEntity(
        id: json['id'] as String,
        contentType: json['contentType'] as String,
        sizeBytes: json['sizeBytes'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

/// [kind]: 'Customer' | 'Staff'. ('InternalNote' không bao giờ trả về cho khách — BE lọc ở `DetailAsync`.)
class SupportMessageEntity {
  final String id;
  final String kind;
  final String body;
  final DateTime createdAt;
  final List<SupportAttachmentEntity> attachments;

  const SupportMessageEntity({
    required this.id,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.attachments,
  });

  factory SupportMessageEntity.fromJson(Map<String, dynamic> json) => SupportMessageEntity(
        id: json['id'] as String,
        kind: json['kind'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        attachments: (json['attachments'] as List)
            .map((e) => SupportAttachmentEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SupportTicketDetailEntity {
  final SupportTicketEntity ticket;
  final List<SupportMessageEntity> messages;

  const SupportTicketDetailEntity({required this.ticket, required this.messages});

  factory SupportTicketDetailEntity.fromJson(Map<String, dynamic> json) => SupportTicketDetailEntity(
        ticket: SupportTicketEntity.fromJson(json['ticket'] as Map<String, dynamic>),
        messages: (json['messages'] as List)
            .map((e) => SupportMessageEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// [scopes]: tên các cờ BE xin xem, mỗi phần tử là 1 tên PascalCase riêng lẻ (không phải số nguyên
/// Flags gộp) — 'Accounts' | 'Transactions' | 'Budgets' | 'Draft'.
/// [status]: 'Pending' | 'Approved' | 'Denied' | 'Revoked'.
class SupportAccessRequestEntity {
  final String id;
  final String ticketId;
  final List<String> scopes;
  final String reason;
  final String status;
  final String? financialAccountId;
  final DateTime createdAt;
  final DateTime requestExpiresAt;
  final DateTime? decidedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  const SupportAccessRequestEntity({
    required this.id,
    required this.ticketId,
    required this.scopes,
    required this.reason,
    required this.status,
    required this.financialAccountId,
    required this.createdAt,
    required this.requestExpiresAt,
    required this.decidedAt,
    required this.expiresAt,
    required this.revokedAt,
  });

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get requiresDraftAccount => scopes.contains('Draft');

  factory SupportAccessRequestEntity.fromJson(Map<String, dynamic> json) => SupportAccessRequestEntity(
        id: json['id'] as String,
        ticketId: json['ticketId'] as String,
        scopes: (json['scopes'] as List).cast<String>(),
        reason: json['reason'] as String,
        status: json['status'] as String,
        financialAccountId: json['financialAccountId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        requestExpiresAt: DateTime.parse(json['requestExpiresAt'] as String).toLocal(),
        decidedAt: json['decidedAt'] == null ? null : DateTime.parse(json['decidedAt'] as String).toLocal(),
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String).toLocal(),
        revokedAt: json['revokedAt'] == null ? null : DateTime.parse(json['revokedAt'] as String).toLocal(),
      );
}

/// [scope]: 1 tên PascalCase riêng lẻ, giống [SupportAccessRequestEntity.scopes].
class SupportAccessLogEntity {
  final String ticketId;
  final String scope;
  final DateTime viewedAt;

  const SupportAccessLogEntity({required this.ticketId, required this.scope, required this.viewedAt});

  factory SupportAccessLogEntity.fromJson(Map<String, dynamic> json) => SupportAccessLogEntity(
        ticketId: json['ticketId'] as String,
        scope: json['scope'] as String,
        viewedAt: DateTime.parse(json['viewedAt'] as String).toLocal(),
      );
}
