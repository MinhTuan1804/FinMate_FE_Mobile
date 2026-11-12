/// Cộng đồng: chia sẻ kinh nghiệm chi tiêu, khó khăn tài chính, câu hỏi, quán ăn/deal tốt.
/// Ẩn danh là mặc định; không response nào có id tác giả — chỉ [CommunityAuthorEntity] (isAnonymous, displayName) và isMine.
/// `createdOn`/`lastSharedOn` chỉ có NGÀY (giờ Việt Nam), không có giờ, nên không áp `.toLocal()` như field DateTimeOffset thường.
/// `status` bài (chỉ có khi isMine) và `status` ảnh là snake_case tự map ở BE (`CommunityRules.Snake`/`.ToLowerInvariant()`),
/// khác enum PascalCase toàn cục — ví dụ "visible"/"auto_hidden"/"removed", "pending"/"approved"/"rejected".
library;

class CommunityAreaEntity {
  final String code;
  final String name;

  const CommunityAreaEntity({required this.code, required this.name});

  factory CommunityAreaEntity.fromJson(Map<String, dynamic> json) =>
      CommunityAreaEntity(code: json['code'] as String, name: json['name'] as String);
}

class CommunityProvinceEntity {
  final String code;
  final String name;
  final List<CommunityAreaEntity> areas;

  const CommunityProvinceEntity({required this.code, required this.name, required this.areas});

  factory CommunityProvinceEntity.fromJson(Map<String, dynamic> json) => CommunityProvinceEntity(
        code: json['code'] as String,
        name: json['name'] as String,
        areas: (json['areas'] as List? ?? const [])
            .map((e) => CommunityAreaEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CommunityTopicEntity {
  final String code;
  final String name;
  final bool requiresPlace;
  final List<String> tags;

  const CommunityTopicEntity({required this.code, required this.name, required this.requiresPlace, required this.tags});

  factory CommunityTopicEntity.fromJson(Map<String, dynamic> json) => CommunityTopicEntity(
        code: json['code'] as String,
        name: json['name'] as String,
        requiresPlace: json['requiresPlace'] as bool? ?? false,
        tags: (json['tags'] as List? ?? const []).cast<String>(),
      );
}

class CommunityProfileEntity {
  final String? provinceCode;
  final String? areaCode;
  final bool promptsEnabled;
  final bool consentGranted;
  final DateTime? mutedUntil;

  const CommunityProfileEntity({
    this.provinceCode,
    this.areaCode,
    required this.promptsEnabled,
    required this.consentGranted,
    this.mutedUntil,
  });

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  factory CommunityProfileEntity.fromJson(Map<String, dynamic> json) => CommunityProfileEntity(
        provinceCode: json['provinceCode'] as String?,
        areaCode: json['areaCode'] as String?,
        promptsEnabled: json['promptsEnabled'] as bool? ?? true,
        consentGranted: json['consentGranted'] as bool? ?? false,
        mutedUntil: json['mutedUntil'] == null ? null : DateTime.parse(json['mutedUntil'] as String).toLocal(),
      );
}

class CommunityAuthorEntity {
  final bool isAnonymous;
  final String? displayName;

  const CommunityAuthorEntity({required this.isAnonymous, this.displayName});

  factory CommunityAuthorEntity.fromJson(Map<String, dynamic> json) => CommunityAuthorEntity(
        isAnonymous: json['isAnonymous'] as bool? ?? true,
        displayName: json['displayName'] as String?,
      );
}

/// Quán gắn trong 1 bài (rút gọn). Khác [CommunityPlaceSummaryEntity] dùng cho danh sách/chi tiết quán.
class CommunityPlaceRefEntity {
  final String id;
  final String name;
  final String provinceCode;
  final String areaCode;
  final String? addressText;

  const CommunityPlaceRefEntity({
    required this.id,
    required this.name,
    required this.provinceCode,
    required this.areaCode,
    this.addressText,
  });

  factory CommunityPlaceRefEntity.fromJson(Map<String, dynamic> json) => CommunityPlaceRefEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        provinceCode: json['provinceCode'] as String,
        areaCode: json['areaCode'] as String,
        addressText: json['addressText'] as String?,
      );
}

/// `status`: "pending" (chỉ tác giả thấy) | "approved" (ai xem được bài cũng thấy) | "rejected".
class CommunityImageEntity {
  final String id;
  final int width;
  final int height;
  final String status;

  const CommunityImageEntity({required this.id, required this.width, required this.height, required this.status});

  bool get isApproved => status == 'approved';

  factory CommunityImageEntity.fromJson(Map<String, dynamic> json) => CommunityImageEntity(
        id: json['id'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        status: json['status'] as String,
      );
}

/// `status` chỉ có giá trị khi `isMine = true` (BE không cho người khác biết bài của ai đang bị ẩn/gỡ):
/// "visible" | "auto_hidden" (tự ẩn do đủ báo cáo, chờ nhân viên) | "removed" (nhân viên đã gỡ).
class CommunityPostEntity {
  final String id;
  final String topic;
  final String? title;
  final String body;
  final List<String> tags;
  final CommunityAuthorEntity author;
  final bool isMine;
  final DateTime createdOn;
  final bool edited;
  final int voteCount;
  final int commentCount;
  final bool votedByMe;
  final bool spentHereVerified;
  final BigInt? priceCents;
  final CommunityPlaceRefEntity? place;
  final List<CommunityImageEntity> images;
  final String? status;

  const CommunityPostEntity({
    required this.id,
    required this.topic,
    this.title,
    required this.body,
    required this.tags,
    required this.author,
    required this.isMine,
    required this.createdOn,
    required this.edited,
    required this.voteCount,
    required this.commentCount,
    required this.votedByMe,
    required this.spentHereVerified,
    this.priceCents,
    this.place,
    required this.images,
    this.status,
  });

  /// true khi bài chỉ là "chạm một lần" ở quán (chủ đề `places`, body rỗng): không hiện bảng tin, không bình luận được.
  bool get isSpentHereOnly => topic == 'places' && body.isEmpty && (title == null || title!.isEmpty);

  factory CommunityPostEntity.fromJson(Map<String, dynamic> json) => CommunityPostEntity(
        id: json['id'] as String,
        topic: json['topic'] as String,
        title: json['title'] as String?,
        body: json['body'] as String? ?? '',
        tags: (json['tags'] as List? ?? const []).cast<String>(),
        author: CommunityAuthorEntity.fromJson((json['author'] as Map<String, dynamic>?) ?? const {}),
        isMine: json['isMine'] as bool? ?? false,
        createdOn: DateTime.parse(json['createdOn'] as String),
        edited: json['edited'] as bool? ?? false,
        voteCount: json['voteCount'] as int? ?? 0,
        commentCount: json['commentCount'] as int? ?? 0,
        votedByMe: json['votedByMe'] as bool? ?? false,
        spentHereVerified: json['spentHereVerified'] as bool? ?? false,
        priceCents: json['priceCents'] == null ? null : BigInt.from(json['priceCents'] as int),
        place: json['place'] == null ? null : CommunityPlaceRefEntity.fromJson(json['place'] as Map<String, dynamic>),
        images: (json['images'] as List? ?? const [])
            .map((e) => CommunityImageEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: json['status'] as String?,
      );
}

class CommunityPostPageEntity {
  final List<CommunityPostEntity> items;
  final String? nextCursor;

  const CommunityPostPageEntity({required this.items, this.nextCursor});

  factory CommunityPostPageEntity.fromJson(Map<String, dynamic> json) => CommunityPostPageEntity(
        items: (json['items'] as List? ?? const [])
            .map((e) => CommunityPostEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

class CommunityVoteEntity {
  final int voteCount;
  final bool votedByMe;

  const CommunityVoteEntity({required this.voteCount, required this.votedByMe});

  factory CommunityVoteEntity.fromJson(Map<String, dynamic> json) =>
      CommunityVoteEntity(voteCount: json['voteCount'] as int? ?? 0, votedByMe: json['votedByMe'] as bool? ?? false);
}

/// Tóm tắt 1 quán, xếp hạng theo điểm = chi thật × 3 + vote + số chia sẻ (tính khi đọc, không lưu sẵn).
class CommunityPlaceSummaryEntity {
  final String id;
  final String name;
  final String provinceCode;
  final String areaCode;
  final String? addressText;
  final int shareCount;
  final int spentHereCount;
  final int voteCount;
  final BigInt? typicalPriceCents;
  final List<String> tags;
  final DateTime lastSharedOn;

  const CommunityPlaceSummaryEntity({
    required this.id,
    required this.name,
    required this.provinceCode,
    required this.areaCode,
    this.addressText,
    required this.shareCount,
    required this.spentHereCount,
    required this.voteCount,
    this.typicalPriceCents,
    required this.tags,
    required this.lastSharedOn,
  });

  factory CommunityPlaceSummaryEntity.fromJson(Map<String, dynamic> json) => CommunityPlaceSummaryEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        provinceCode: json['provinceCode'] as String,
        areaCode: json['areaCode'] as String,
        addressText: json['addressText'] as String?,
        shareCount: json['shareCount'] as int? ?? 0,
        spentHereCount: json['spentHereCount'] as int? ?? 0,
        voteCount: json['voteCount'] as int? ?? 0,
        typicalPriceCents: json['typicalPriceCents'] == null ? null : BigInt.from(json['typicalPriceCents'] as int),
        tags: (json['tags'] as List? ?? const []).cast<String>(),
        lastSharedOn: DateTime.parse(json['lastSharedOn'] as String),
      );
}

class CommunityPlacePageEntity {
  final List<CommunityPlaceSummaryEntity> items;
  final String? nextCursor;

  const CommunityPlacePageEntity({required this.items, this.nextCursor});

  factory CommunityPlacePageEntity.fromJson(Map<String, dynamic> json) => CommunityPlacePageEntity(
        items: (json['items'] as List? ?? const [])
            .map((e) => CommunityPlaceSummaryEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

class CommunityPlaceDetailEntity {
  final CommunityPlaceSummaryEntity place;
  final List<CommunityPostEntity> posts;

  const CommunityPlaceDetailEntity({required this.place, required this.posts});

  factory CommunityPlaceDetailEntity.fromJson(Map<String, dynamic> json) => CommunityPlaceDetailEntity(
        place: CommunityPlaceSummaryEntity.fromJson(json['place'] as Map<String, dynamic>),
        posts: (json['posts'] as List? ?? const [])
            .map((e) => CommunityPostEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CommunityCommentEntity {
  final String id;
  final String body;
  final CommunityAuthorEntity author;
  final bool isMine;
  final DateTime createdOn;
  final bool edited;

  const CommunityCommentEntity({
    required this.id,
    required this.body,
    required this.author,
    required this.isMine,
    required this.createdOn,
    required this.edited,
  });

  factory CommunityCommentEntity.fromJson(Map<String, dynamic> json) => CommunityCommentEntity(
        id: json['id'] as String,
        body: json['body'] as String,
        author: CommunityAuthorEntity.fromJson((json['author'] as Map<String, dynamic>?) ?? const {}),
        isMine: json['isMine'] as bool? ?? false,
        createdOn: DateTime.parse(json['createdOn'] as String),
        edited: json['edited'] as bool? ?? false,
      );
}

class CommunityCommentPageEntity {
  final List<CommunityCommentEntity> items;
  final String? nextCursor;

  const CommunityCommentPageEntity({required this.items, this.nextCursor});

  factory CommunityCommentPageEntity.fromJson(Map<String, dynamic> json) => CommunityCommentPageEntity(
        items: (json['items'] as List? ?? const [])
            .map((e) => CommunityCommentEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

/// `GET /share-prompt?transactionId=`: hỏi 1 lần sau khi lưu/xác nhận giao dịch có nên chia sẻ quán không.
class CommunitySharePromptEntity {
  final bool shouldPrompt;
  final String? suggestedPlaceName;
  final BigInt? suggestedPriceCents;
  final List<CommunityPlaceRefEntity> existingPlaces;

  const CommunitySharePromptEntity({
    required this.shouldPrompt,
    this.suggestedPlaceName,
    this.suggestedPriceCents,
    required this.existingPlaces,
  });

  factory CommunitySharePromptEntity.fromJson(Map<String, dynamic> json) => CommunitySharePromptEntity(
        shouldPrompt: json['shouldPrompt'] as bool? ?? false,
        suggestedPlaceName: json['suggestedPlaceName'] as String?,
        suggestedPriceCents:
            json['suggestedPriceCents'] == null ? null : BigInt.from(json['suggestedPriceCents'] as int),
        existingPlaces: (json['existingPlaces'] as List? ?? const [])
            .map((e) => CommunityPlaceRefEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
