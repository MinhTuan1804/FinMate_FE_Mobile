import 'package:finmate/core/format/money.dart';

/// Một bằng chứng của câu trả lời agent (màn "Vì sao?"). `valueVnd` là số nguyên đồng, null khi bằng chứng chỉ là chữ.
/// `confidence` là độ đầy đủ × độ mới, KHÔNG phải xác suất: không hiển thị dạng phần trăm.
class AgentEvidence {
  final String id;
  final String text;
  final BigInt? valueVnd;
  final String unit;

  /// confirmed | user_entered | estimated | document
  final String source;
  final String? sourceName;
  final DateTime? asOf;
  final double confidence;

  const AgentEvidence({
    required this.id,
    required this.text,
    this.valueVnd,
    this.unit = '',
    this.source = 'estimated',
    this.sourceName,
    this.asOf,
    this.confidence = 0,
  });

  factory AgentEvidence.fromJson(Map<String, dynamic> json) => AgentEvidence(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        valueVnd: json['valueVnd'] == null ? null : parseCents(json['valueVnd']),
        unit: json['unit'] as String? ?? '',
        source: json['source'] as String? ?? 'estimated',
        sourceName: json['sourceName'] as String?,
        asOf: json['asOf'] == null ? null : DateTime.tryParse(json['asOf'].toString())?.toLocal(),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// Một mệnh đề của câu trả lời; mọi `evidenceIds` nằm trong `evidence` của chính lượt này.
class AgentClaim {
  final String text;
  final List<String> evidenceIds;

  const AgentClaim({required this.text, this.evidenceIds = const []});

  factory AgentClaim.fromJson(Map<String, dynamic> json) => AgentClaim(
        text: json['text'] as String? ?? '',
        evidenceIds: [for (final e in (json['evidenceIds'] as List? ?? const [])) e.toString()],
      );
}

/// Thẻ đề xuất hành động do công cụ của agent sinh ra (không do LLM viết). Chỉ là đề xuất: người dùng bấm thì app mới gọi API có sẵn.
class AgentSuggestedAction {
  static const waitUntil = 'wait_until';
  static const lowerAmountTo = 'lower_amount_to';
  static const setBudgetLimit = 'set_budget_limit';
  static const createGoal = 'create_goal';
  static const changeGoalDeadline = 'change_goal_deadline';

  final String kind;
  final String title;
  final BigInt? amountVnd;
  final DateTime? date;
  final String? categorySlug;
  final String? categoryName;

  /// Id đối tượng bị tác động (mục tiêu của `change_goal_deadline`)
  final String? targetId;

  const AgentSuggestedAction({
    required this.kind,
    required this.title,
    this.amountVnd,
    this.date,
    this.categorySlug,
    this.categoryName,
    this.targetId,
  });

  bool get _hasAmount => (amountVnd ?? BigInt.zero) > BigInt.zero;

  /// Có nút bấm không. Mỗi loại một việc, và chỉ khi thẻ có đủ dữ liệu cho việc đó:
  /// `set_budget_limit` đặt hạn mức; `create_goal` tạo mục tiêu (số tiền + hạn); `change_goal_deadline` đổi hạn mục tiêu đã có (id + hạn mới);
  /// `lower_amount_to` kiểm tra lại khoản mua với giá thấp hơn; `wait_until` hẹn nhắc đúng ngày. Loại lạ (backend mới hơn app) không có nút, vẫn hiện chữ.
  bool get canApply => switch (kind) {
        setBudgetLimit => categorySlug != null && _hasAmount,
        createGoal => _hasAmount && date != null,
        changeGoalDeadline => (targetId ?? '').isNotEmpty && date != null,
        lowerAmountTo => _hasAmount,
        waitUntil => date != null,
        _ => false,
      };

  String get applyLabel => switch (kind) {
        createGoal => 'Tạo mục tiêu',
        changeGoalDeadline => 'Đổi hạn',
        lowerAmountTo => 'Kiểm tra lại',
        waitUntil => 'Nhắc tôi',
        _ => 'Đặt hạn mức',
      };

  String get busyLabel => switch (kind) {
        createGoal => 'Đang tạo...',
        changeGoalDeadline => 'Đang đổi...',
        lowerAmountTo => 'Đang kiểm tra...',
        waitUntil => 'Đang hẹn...',
        _ => 'Đang đặt...',
      };

  String get doneLabel => switch (kind) {
        createGoal => 'Đã tạo',
        changeGoalDeadline => 'Đã đổi hạn',
        lowerAmountTo => 'Đã kiểm tra',
        waitUntil => 'Đã hẹn',
        _ => 'Đã đặt',
      };

  factory AgentSuggestedAction.fromJson(Map<String, dynamic> json) => AgentSuggestedAction(
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        amountVnd: json['amountVnd'] == null ? null : parseCents(json['amountVnd']),
        date: json['date'] == null ? null : DateTime.tryParse(json['date'].toString()),
        categorySlug: json['categorySlug'] as String?,
        categoryName: json['categoryName'] as String?,
        targetId: json['targetId'] as String?,
      );
}

/// Phản hồi của `POST /api/v1/agent/ask`.
class AgentAnswer {
  static const answered = 'answered';
  static const clarify = 'clarify';
  static const refused = 'refused';
  static const insufficientData = 'insufficient_data';

  final String status;
  final String? message;
  final List<AgentClaim> claims;
  final List<AgentEvidence> evidence;

  /// feasible | tight | infeasible, hoặc null
  final String? verdict;
  final bool usedTemplate;
  final List<AgentSuggestedAction> suggestedActions;

  const AgentAnswer({
    required this.status,
    this.message,
    this.claims = const [],
    this.evidence = const [],
    this.verdict,
    this.usedTemplate = false,
    this.suggestedActions = const [],
  });

  bool get isAnswered => status == answered;

  AgentEvidence? evidenceById(String id) => evidence.where((e) => e.id == id).firstOrNull;

  /// Câu trả lời của công cụ `goal_plan` (đánh giá một mục tiêu tiết kiệm): có số tiền mục tiêu và số cần góp mỗi tháng. App hiện thẻ tóm tắt (kết luận + hai con số chính) thay cho đoạn văn dài.
  bool get isGoalPlan => evidenceById('goal_target') != null && evidenceById('plan_required') != null;

  /// Id của bằng chứng ghi chú "ước tính sơ bộ" (backend, công cụ `goal_plan`) khi mới có thu nhập đã khai và/hoặc cách quản lý đã chọn, chưa đủ chi tiêu thật
  static const preliminaryNoteId = 'prelim_note';

  /// Ghi chú cố định dưới thẻ khi số liệu chỉ là ước tính sơ bộ (không phụ thuộc việc LLM có nhắc trong câu trả lời hay không); null nếu số liệu dựa trên dữ liệu thật
  String? get preliminaryNote => evidenceById(preliminaryNoteId)?.text;

  factory AgentAnswer.fromJson(Map<String, dynamic> json) => AgentAnswer(
        status: json['status'] as String? ?? insufficientData,
        message: json['message'] as String?,
        claims: [for (final c in (json['claims'] as List? ?? const [])) AgentClaim.fromJson(c as Map<String, dynamic>)],
        evidence: [for (final e in (json['evidence'] as List? ?? const [])) AgentEvidence.fromJson(e as Map<String, dynamic>)],
        verdict: json['verdict'] as String?,
        usedTemplate: json['usedTemplate'] as bool? ?? false,
        suggestedActions: [
          for (final a in (json['suggestedActions'] as List? ?? const [])) AgentSuggestedAction.fromJson(a as Map<String, dynamic>),
        ],
      );
}
