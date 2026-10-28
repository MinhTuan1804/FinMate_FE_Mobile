import 'package:uuid/uuid.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Nguồn của bản nháp, ánh xạ sang `source` khi lưu giao dịch
enum DraftSource {
  chat('Manual'),
  voice('Voice'),
  receipt('Receipt');

  final String apiValue;
  const DraftSource(this.apiValue);
}

enum DraftKind { expense, transfer }

const _genericReply = 'Mình chưa hiểu phản hồi này. Bạn thử lại nhé.';

DateTime? _parseDate(Object? value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

BigInt? _parseOptionalCents(Object? value) => value == null ? null : parseCents(value);

TransactionType? _parseOptionalType(Object? value) => value == null ? null : TransactionType.fromApi(value.toString());

/// Các trường bắt buộc mà bản nháp từ parse/scan chưa có
List<String> _deriveMissing({required BigInt? amount, required String? categorySlug}) => [
      if (amount == null) 'amount',
      if (categorySlug == null) 'category',
    ];

/// Một món trên hóa đơn; số tiền là giá gốc (chưa trừ giảm giá)
class ReceiptGroupItem {
  final String name;
  final BigInt amountCents;

  const ReceiptGroupItem({required this.name, required this.amountCents});

  factory ReceiptGroupItem.fromJson(Map<String, dynamic> json) => ReceiptGroupItem(
        name: json['name'] is String ? json['name'] as String : '',
        amountCents: parseCents(json['amountCents']),
      );
}

/// Một nhóm danh mục của hóa đơn đã tách; [categorySlug] null là nhóm "chưa phân loại".
/// [amountCents] là số đã trừ giảm giá/cộng phụ phí, các nhóm cộng lại đúng bằng tổng bill.
class ReceiptGroup {
  final String? categorySlug;
  final BigInt amountCents;
  final List<ReceiptGroupItem> items;

  /// Mã giao dịch cùng số tiền vừa ghi gần đây (BE chỉ cảnh báo, không chặn); null = không thấy trùng
  final String? possibleDuplicateId;

  const ReceiptGroup({this.categorySlug, required this.amountCents, this.items = const [], this.possibleDuplicateId});

  /// Giá trị `receiptGroup` gửi khi lưu: slug gốc của nhóm, hoặc "unknown" khi nhóm không có slug
  String get apiKey => categorySlug ?? 'unknown';

  /// clientRequestId cố định theo lần quét + nhóm: mở lại thẻ rồi lưu lại thì BE trả giao dịch đã có thay vì tạo trùng.
  /// Không có [scanId] thì không có gì để cố định, dùng id ngẫu nhiên.
  String requestId(String? scanId) =>
      scanId == null ? const Uuid().v4() : const Uuid().v5(Namespace.url.value, 'finmate:receipt:$scanId:$apiKey');

  factory ReceiptGroup.fromJson(Map<String, dynamic> json) => ReceiptGroup(
        categorySlug: json['categorySlug'] is String ? json['categorySlug'] as String : null,
        amountCents: parseCents(json['amountCents']),
        items: _parseList(json['items'], ReceiptGroupItem.fromJson),
        possibleDuplicateId: json['possibleDuplicateTransactionId'] as String?,
      );
}

/// Bỏ qua phần tử không phải object thay vì ném (BE cũ không trả, phản hồi lạ)
List<T> _parseList<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is List ? value.whereType<Map<String, dynamic>>().map(parse).toList() : <T>[];

/// Bản nháp giao dịch do AI trích xuất (từ chat `confirm`, `parse` hoặc `scan-receipt`); người dùng rà soát rồi mới lưu.
class DraftTransaction {
  final DraftKind kind;
  final BigInt? amountCents;
  final TransactionType? type;
  final String? merchantName;
  final String? description;
  final String? categorySlug;
  final String? suggestedAccountId;
  final List<String> missingFields;
  final DraftSource source;
  final DateTime? transactedAt;
  final double? confidence;

  /// Mã lần quét do `scan-receipt` trả về; gửi lại khi Lưu để BE nối bản ghi quét với giao dịch
  final String? scanId;

  /// Các nhóm của hóa đơn đã tách theo món; rỗng khi bill không tách (đi đường cũ)
  final List<ReceiptGroup> receiptGroups;

  /// Mã giao dịch cùng số tiền vừa ghi gần đây (BE chỉ cảnh báo, không chặn); null = không thấy trùng
  final String? possibleDuplicateId;

  /// Hóa đơn mà BE thấy chưa chắc (OCR nghi ngờ, nhiều phần chưa rõ nhóm...): nên kiểm tra lại trước khi lưu
  final bool needsReview;

  /// Cả bill hoặc một nhóm trong bill có thể trùng với giao dịch đã ghi
  bool get hasPossibleDuplicate => possibleDuplicateId != null || hasGroupDuplicate;

  bool get hasGroupDuplicate => receiptGroups.any((g) => g.possibleDuplicateId != null);

  const DraftTransaction({
    this.kind = DraftKind.expense,
    this.amountCents,
    this.type,
    this.merchantName,
    this.description,
    this.categorySlug,
    this.suggestedAccountId,
    this.missingFields = const [],
    this.source = DraftSource.chat,
    this.transactedAt,
    this.confidence,
    this.scanId,
    this.receiptGroups = const [],
    this.possibleDuplicateId,
    this.needsReview = false,
  });

  /// Từ `draft` của `POST /transactions/chat` (action == confirm)
  factory DraftTransaction.fromChatJson(Map<String, dynamic> json, {DraftSource source = DraftSource.chat}) {
    final kind = json['kind'] == 'transfer' ? DraftKind.transfer : DraftKind.expense;
    return DraftTransaction(
      kind: kind,
      amountCents: _parseOptionalCents(json['amountCents']),
      type: kind == DraftKind.transfer ? TransactionType.transfer : _parseOptionalType(json['transactionType']),
      merchantName: json['merchantName'] as String?,
      description: json['description'] as String?,
      categorySlug: json['categorySlug'] as String?,
      suggestedAccountId: json['suggestedFinancialAccountId'] as String?,
      missingFields: ((json['missingFields'] as List?) ?? const []).map((e) => e.toString()).toList(),
      source: source,
      // `occurredAt`: ngày nói trong câu ("hôm qua"); không có thì để trống, màn rà soát dùng giờ hiện tại
      transactedAt: _parseDate(json['occurredAt'] ?? json['transactedAt']),
      possibleDuplicateId: json['possibleDuplicateTransactionId'] as String?,
    );
  }

  /// Từ `data` của `POST /transactions/parse` (stateless, mọi trường có thể null)
  factory DraftTransaction.fromParseJson(Map<String, dynamic> json, {DraftSource source = DraftSource.chat}) {
    final amount = _parseOptionalCents(json['amountCents']);
    final slug = json['categorySlug'] as String?;
    return DraftTransaction(
      amountCents: amount,
      type: _parseOptionalType(json['transactionType']),
      merchantName: json['merchantName'] as String?,
      description: json['description'] as String?,
      categorySlug: slug,
      missingFields: _deriveMissing(amount: amount, categorySlug: slug),
      source: source,
      transactedAt: _parseDate(json['transactedAt']),
    );
  }

  DraftTransaction copyWith({
    DraftKind? kind,
    BigInt? amountCents,
    TransactionType? type,
    String? merchantName,
    String? description,
    String? categorySlug,
    String? suggestedAccountId,
    List<String>? missingFields,
    DraftSource? source,
    DateTime? transactedAt,
    double? confidence,
    String? scanId,
    List<ReceiptGroup>? receiptGroups,
    String? possibleDuplicateId,
    bool? needsReview,
  }) {
    return DraftTransaction(
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      merchantName: merchantName ?? this.merchantName,
      description: description ?? this.description,
      categorySlug: categorySlug ?? this.categorySlug,
      suggestedAccountId: suggestedAccountId ?? this.suggestedAccountId,
      missingFields: missingFields ?? this.missingFields,
      source: source ?? this.source,
      transactedAt: transactedAt ?? this.transactedAt,
      confidence: confidence ?? this.confidence,
      scanId: scanId ?? this.scanId,
      receiptGroups: receiptGroups ?? this.receiptGroups,
      possibleDuplicateId: possibleDuplicateId ?? this.possibleDuplicateId,
      needsReview: needsReview ?? this.needsReview,
    );
  }
}

/// Một đơn trong ảnh danh sách đơn hàng thành bản nháp chi tiêu (không nối `scanId`: mỗi đơn lưu độc lập)
DraftTransaction _orderDraft(Map<String, dynamic> json) {
  final amount = _parseOptionalCents(json['amountCents']);
  final slug = json['categorySlug'] as String?;
  return DraftTransaction(
    amountCents: amount,
    type: TransactionType.expense,
    merchantName: json['merchantName'] as String?,
    description: json['description'] as String?,
    categorySlug: slug,
    missingFields: _deriveMissing(amount: amount, categorySlug: slug),
    source: DraftSource.receipt,
  );
}

/// Kết quả `POST /transactions/scan-receipt`
class ReceiptScan {
  final bool success;
  final DraftTransaction draft;
  final String? scanId;
  final List<ReceiptGroup> groups;

  /// Ảnh chụp màn hình danh sách đơn ("Đơn đã mua"): mỗi đơn một bản nháp, lưu độc lập (không nối bản ghi quét). Rỗng với hóa đơn thường.
  final List<DraftTransaction> orders;

  /// Số đơn bị cắt dở ở mép ảnh nên chưa đọc được tiền
  final int incompleteOrders;

  const ReceiptScan({required this.success, required this.draft, this.scanId, this.groups = const [], this.orders = const [], this.incompleteOrders = 0});

  factory ReceiptScan.fromJson(Map<String, dynamic> json) {
    final amount = _parseOptionalCents(json['amountCents']);
    final slug = json['categorySlug'] as String?;
    final groups = _parseList(json['groups'], ReceiptGroup.fromJson);
    return ReceiptScan(
      success: json['ocrResult'] == 'success',
      scanId: json['scanId'] as String?,
      groups: groups,
      orders: _parseList(json['orders'], _orderDraft),
      incompleteOrders: (json['incompleteOrders'] as num?)?.toInt() ?? 0,
      draft: DraftTransaction(
        amountCents: amount,
        type: _parseOptionalType(json['transactionType']),
        merchantName: json['merchantName'] as String?,
        categorySlug: slug,
        missingFields: _deriveMissing(amount: amount, categorySlug: slug),
        source: DraftSource.receipt,
        transactedAt: _parseDate(json['transactedAt']),
        confidence: (json['confidence'] as num?)?.toDouble(),
        scanId: json['scanId'] as String?,
        receiptGroups: groups,
        possibleDuplicateId: json['possibleDuplicateTransactionId'] as String?,
        needsReview: json['needsReview'] == true,
      ),
    );
  }
}

class ChatSummaryItem {
  final String slug;
  final String name;
  final BigInt amountCents;
  final double share;

  const ChatSummaryItem({required this.slug, required this.name, required this.amountCents, required this.share});

  factory ChatSummaryItem.fromJson(Map<String, dynamic> json) => ChatSummaryItem(
        slug: json['categorySlug'] as String? ?? '',
        name: json['categoryName'] as String? ?? 'Chưa phân loại',
        amountCents: parseCents(json['amountCents']),
        share: (json['share'] as num?)?.toDouble() ?? 0,
      );
}

/// Số liệu tóm tắt chi tiêu do chatbot trả về (action == summary)
class ChatSummary {
  final String metric;
  final String periodLabel;
  final BigInt totalCents;
  final BigInt incomeCents;
  final BigInt expenseCents;
  final BigInt leftCents;
  final List<ChatSummaryItem> items;

  const ChatSummary({
    required this.metric,
    required this.periodLabel,
    required this.totalCents,
    required this.incomeCents,
    required this.expenseCents,
    required this.leftCents,
    required this.items,
  });

  factory ChatSummary.fromJson(Map<String, dynamic> json) => ChatSummary(
        metric: json['metric'] as String? ?? 'expense',
        periodLabel: json['periodLabel'] as String? ?? '',
        totalCents: parseCents(json['totalCents']),
        incomeCents: parseCents(json['incomeCents']),
        expenseCents: parseCents(json['expenseCents']),
        leftCents: parseCents(json['leftCents']),
        items: ((json['items'] as List?) ?? const []).map((e) => ChatSummaryItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Phản hồi của `POST /transactions/voice`: câu STT nghe được + kết quả chat y hệt gõ chữ
class VoiceReply {
  final String transcript;
  final ChatReply chat;

  const VoiceReply({required this.transcript, required this.chat});

  factory VoiceReply.fromJson(Map<String, dynamic> json) => VoiceReply(
        transcript: (json['transcript'] as String?)?.trim() ?? '',
        chat: ChatReply.fromJson((json['chat'] as Map<String, dynamic>?) ?? const {}),
      );
}

/// Một khoản trong phản hồi `POST /chat/analyze` (backend chỉ HIỂU câu, không ghi gì)
class AnalyzedEntry {
  final String kind; // expense | income | transfer
  final BigInt amountCents;
  final String? description;
  final String? merchantName;
  final String? categorySlug;

  /// rule = từ khóa quyết định; cache = chỉ là gợi ý từ bảng nhớ chung; null = chưa biết (hoặc server cũ chưa trả trường này)
  final String? categorySource;
  final String? incomeType;
  final bool autoSaveOk;
  final bool toOthers;
  final DateTime? occurredAt;

  const AnalyzedEntry({
    required this.kind,
    required this.amountCents,
    this.description,
    this.merchantName,
    this.categorySlug,
    this.categorySource,
    this.incomeType,
    this.autoSaveOk = false,
    this.toOthers = false,
    this.occurredAt,
  });

  factory AnalyzedEntry.fromJson(Map<String, dynamic> json) {
    final slug = json['categorySlug'] as String?;
    return AnalyzedEntry(
      kind: json['kind'] as String? ?? 'expense',
      amountCents: _parseOptionalCents(json['amountCents']) ?? BigInt.zero,
      description: json['description'] as String?,
      merchantName: json['merchantName'] as String?,
      categorySlug: (slug == null || slug.isEmpty) ? null : slug,
      categorySource: json['categorySource'] as String?,
      incomeType: json['incomeType'] as String?,
      autoSaveOk: json['autoSaveOk'] == true,
      toOthers: json['toOthers'] == true,
      occurredAt: _parseDate(json['occurredAt']),
    );
  }
}

/// Bản nháp MỤC TIÊU TIẾT KIỆM từ câu chat ("đặt mục tiêu vào 2 tháng sau tôi sẽ mua xe máy khoảng 50 triệu"). Chưa tạo gì: người dùng xác nhận
/// rồi app gọi `POST /saving-goals`. Hạn chốt 23:59:59 giờ Việt Nam; [deadlineText] là cụm người dùng nói, hiện kèm ngày cụ thể để họ soát.
class GoalDraft {
  final String name;

  /// Người dùng không nói tên nên [name] là tên mặc định; thẻ cho sửa
  final bool nameIsDefault;
  final BigInt targetCents;
  final DateTime? deadline;
  final String? deadlineText;

  const GoalDraft({required this.name, this.nameIsDefault = false, required this.targetCents, this.deadline, this.deadlineText});

  factory GoalDraft.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'] as String?;
    return GoalDraft(
      name: (json['name'] as String?)?.trim().isNotEmpty == true ? (json['name'] as String).trim() : 'Mục tiêu tiết kiệm',
      nameIsDefault: json['nameIsDefault'] == true,
      targetCents: parseCents(json['targetCents']),
      deadline: deadline == null ? null : DateTime.tryParse(deadline)?.toLocal(),
      deadlineText: json['deadlineText'] as String?,
    );
  }

  /// Sửa tên thì không còn là tên mặc định; [clearDeadline] bỏ hạn (không hạn là hợp lệ)
  GoalDraft copyWith({String? name, BigInt? targetCents, DateTime? deadline, bool clearDeadline = false}) => GoalDraft(
        name: name ?? this.name,
        nameIsDefault: name != null ? false : nameIsDefault,
        targetCents: targetCents ?? this.targetCents,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        // đổi hạn bằng tay thì cụm đã nói không còn đúng nữa
        deadlineText: clearDeadline || deadline != null ? null : deadlineText,
      );

  /// Số tiền cần nạp mỗi tháng để kịp hạn (làm tròn lên, tối thiểu 1 tháng); null nếu không có hạn. Cùng công thức với `SavingsGoalEntity.requiredPerMonth`.
  BigInt? requiredPerMonth({DateTime? asOf}) {
    final due = deadline;
    if (due == null) return null;
    final now = asOf ?? DateTime.now();
    final months = ((due.year - now.year) * 12 + due.month - now.month).clamp(1, 1200);
    return (targetCents + BigInt.from(months - 1)) ~/ BigInt.from(months);
  }
}

/// Phản hồi `POST /chat/analyze`: server chỉ hiểu câu; quyết định ghi hay hỏi do app làm (xem `LocalChatDecider`)
class ChatAnalysis {
  final String intent;
  final String? replyText;
  final List<AnalyzedEntry> entries;

  /// Câu đặt mục tiêu tiết kiệm (intent create_goal); null khi không phải hoặc đang hỏi lại ([replyText])
  final GoalDraft? goal;

  /// Có câu hỏi tổng ("tháng này tôi tiêu bao nhiêu"): vẫn đi đường server cho đến khi lịch sử nằm đủ ở máy
  final bool hasQuery;

  /// Tổng người dùng nói ("tổng cộng 100k") và có khác tổng các khoản đọc được không
  final int? totalAmount;
  final bool totalMismatch;

  /// Vế trong câu nhiều khoản không có số tiền; không thành khoản
  final List<String> skipped;

  const ChatAnalysis({
    required this.intent,
    this.replyText,
    this.entries = const [],
    this.hasQuery = false,
    this.totalAmount,
    this.totalMismatch = false,
    this.skipped = const [],
    this.goal,
  });

  factory ChatAnalysis.fromJson(Map<String, dynamic> json) {
    final entries = _parseList(json['entries'], AnalyzedEntry.fromJson);
    final single = json['entry'];
    return ChatAnalysis(
      intent: json['intent'] as String? ?? 'out_of_scope',
      replyText: json['replyText'] as String?,
      entries: entries.isNotEmpty ? entries : (single is Map<String, dynamic> ? [AnalyzedEntry.fromJson(single)] : const []),
      hasQuery: json['query'] != null,
      totalAmount: (json['totalAmount'] as num?)?.toInt(),
      totalMismatch: json['totalMismatch'] == true,
      skipped: ((json['skipped'] as List?) ?? const []).map((e) => e.toString()).toList(),
      goal: json['goal'] is Map<String, dynamic> ? GoalDraft.fromJson(json['goal'] as Map<String, dynamic>) : null,
    );
  }
}

/// Phản hồi `POST /chat/analyze-voice`: câu STT nghe được + kết quả hiểu câu đó
class VoiceAnalysis {
  final String transcript;
  final ChatAnalysis analysis;

  const VoiceAnalysis({required this.transcript, required this.analysis});

  factory VoiceAnalysis.fromJson(Map<String, dynamic> json) => VoiceAnalysis(
        transcript: (json['transcript'] as String?)?.trim() ?? '',
        analysis: ChatAnalysis.fromJson((json['parse'] as Map<String, dynamic>?) ?? const {}),
      );
}

enum ChatAction { saved, summary, reply, confirm, goal }

/// Phản hồi của `POST /transactions/chat`
class ChatReply {
  final ChatAction action;
  final String? intent;
  final String? replyText;
  final TransactionEntity? transaction;
  final DraftTransaction? draft;

  /// Mọi bản nháp của câu (nhiều khoản trong một câu); [draft] là phần tử đầu. BE cũ không có `drafts` thì chỉ có một phần tử.
  final List<DraftTransaction> drafts;
  final ChatSummary? summary;

  /// Bản nháp mục tiêu tiết kiệm khi [action] là [ChatAction.goal]
  final GoalDraft? goal;

  const ChatReply({required this.action, this.intent, this.replyText, this.transaction, this.draft, this.drafts = const [], this.summary, this.goal});

  /// Phản hồi lạ hoặc thiếu dữ liệu tương ứng với `action` → trả lời văn bản chung, không ném
  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final intent = json['intent'] as String?;
    final replyText = json['replyText'] as String?;
    ChatReply generic() => ChatReply(action: ChatAction.reply, intent: intent, replyText: replyText ?? _genericReply);

    try {
      switch (json['action']) {
        case 'saved':
          final tx = json['transaction'];
          if (tx is! Map<String, dynamic>) return generic();
          return ChatReply(action: ChatAction.saved, intent: intent, transaction: TransactionEntity.fromJson(tx));
        case 'summary':
          final summary = json['summary'];
          if (summary is! Map<String, dynamic>) return generic();
          return ChatReply(action: ChatAction.summary, intent: intent, summary: ChatSummary.fromJson(summary));
        case 'confirm':
          final draft = json['draft'];
          if (draft is! Map<String, dynamic>) return generic();
          final drafts = _parseList(json['drafts'], DraftTransaction.fromChatJson);
          // `draft` luôn là bản đầu: dùng cùng một đối tượng để hai chỗ không lệch nhau.
          final all = drafts.isEmpty ? [DraftTransaction.fromChatJson(draft)] : drafts;
          return ChatReply(action: ChatAction.confirm, intent: intent, replyText: replyText, draft: all.first, drafts: all);
        case 'goal':
          final goal = json['goal'];
          if (goal is! Map<String, dynamic>) return generic();
          return ChatReply(action: ChatAction.goal, intent: intent, replyText: replyText, goal: GoalDraft.fromJson(goal));
        case 'reply':
          return ChatReply(action: ChatAction.reply, intent: intent, replyText: replyText ?? _genericReply);
        default:
          return generic();
      }
    } catch (_) {
      return generic();
    }
  }
}
