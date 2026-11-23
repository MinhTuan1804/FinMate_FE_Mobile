class SurveyOptionEntity {
  final String code;
  final String text;

  /// Khoảng % thu nhập của đáp án câu chi linh hoạt; [shareMaxPct] null = "từ mức này trở lên".
  final int? shareMinPct;
  final int? shareMaxPct;

  const SurveyOptionEntity({required this.code, required this.text, this.shareMinPct, this.shareMaxPct});

  factory SurveyOptionEntity.fromJson(Map<String, dynamic> json) => SurveyOptionEntity(
        code: json['code'] as String,
        text: json['text'] as String,
        shareMinPct: json['shareMinPct'] as int?,
        shareMaxPct: json['shareMaxPct'] as int?,
      );
}

/// Một câu hỏi khảo sát. [showIf] null = luôn hỏi; không null thì dùng [isVisibleGiven] để tự ẩn/hiện
/// trên máy đúng như BE (xem `ShowIfEvaluator` phía BE) — không cần gọi lại API khi người dùng đổi đáp án.
class SurveyQuestionEntity {
  final String code;
  final String group;
  final String text;
  final Map<String, dynamic>? showIf;
  final List<SurveyOptionEntity> options;

  /// 'choice' (chọn đáp án) hoặc 'amount' (nhập số tiền, không có đáp án).
  final String answerType;

  /// Vai trò trong kế hoạch tháng: 'income' | 'fixed' | 'flexible' | 'savings_balance'; null = câu chọn phương pháp.
  final String? planRole;
  final String? categorySlug;

  const SurveyQuestionEntity({
    required this.code,
    required this.group,
    required this.text,
    required this.showIf,
    required this.options,
    this.answerType = 'choice',
    this.planRole,
    this.categorySlug,
  });

  bool get isAmount => answerType == 'amount';
  bool get isFlexible => planRole == 'flexible';

  /// Giữ nguyên logic `ShowIfEvaluator.IsVisible` phía BE: showIf null/hỏng → luôn hiện; dạng
  /// `{"all":[{"question":mã,"in":[...]} | {"question":mã,"not_in":[...]}]}`; câu chưa trả lời
  /// không nằm trong "in" (sai) và không nằm trong "not_in" (đúng).
  bool isVisibleGiven(Map<String, String> answers) {
    final condition = showIf;
    if (condition == null) return true;
    final all = condition['all'];
    if (all is! List) return true;

    for (final raw in all) {
      if (raw is! Map) continue;
      final question = raw['question'] as String?;
      final answered = question != null ? answers[question] : null;

      if (raw.containsKey('in')) {
        final inList = (raw['in'] as List?)?.whereType<String>().toList() ?? const [];
        if (answered == null || !inList.contains(answered)) return false;
      } else if (raw.containsKey('not_in')) {
        final notInList = (raw['not_in'] as List?)?.whereType<String>().toList() ?? const [];
        if (answered != null && notInList.contains(answered)) return false;
      }
    }
    return true;
  }

  factory SurveyQuestionEntity.fromJson(Map<String, dynamic> json) => SurveyQuestionEntity(
        code: json['code'] as String,
        group: json['group'] as String,
        text: json['text'] as String,
        showIf: json['showIf'] as Map<String, dynamic>?,
        options: (json['options'] as List).map((e) => SurveyOptionEntity.fromJson(e as Map<String, dynamic>)).toList(),
        answerType: json['answerType'] as String? ?? 'choice',
        planRole: json['planRole'] as String?,
        categorySlug: json['categorySlug'] as String?,
      );
}

/// Câu chọn có [optionCode]; câu nhập số tiền có [amountVnd] (đồng). Không bao giờ có cả hai.
class SurveyAnswerEntity {
  final String questionCode;
  final String? optionCode;
  final int? amountVnd;

  const SurveyAnswerEntity({required this.questionCode, this.optionCode, this.amountVnd});

  factory SurveyAnswerEntity.fromJson(Map<String, dynamic> json) => SurveyAnswerEntity(
        questionCode: json['questionCode'] as String,
        optionCode: json['optionCode'] as String?,
        amountVnd: (json['amountVnd'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => amountVnd != null
      ? {'questionCode': questionCode, 'amountVnd': amountVnd}
      : {'questionCode': questionCode, 'optionCode': optionCode};
}

/// [status]: 'pending' | 'completed' | 'skipped'.
class SurveyEntity {
  final String status;
  final DateTime? completedAt;
  final List<SurveyQuestionEntity> questions;
  final List<SurveyAnswerEntity> answers;

  const SurveyEntity({
    required this.status,
    required this.completedAt,
    required this.questions,
    required this.answers,
  });

  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';
  bool get isPending => status == 'pending';

  factory SurveyEntity.fromJson(Map<String, dynamic> json) => SurveyEntity(
        status: json['status'] as String,
        completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String).toLocal(),
        questions: (json['questions'] as List).map((e) => SurveyQuestionEntity.fromJson(e as Map<String, dynamic>)).toList(),
        answers: (json['answers'] as List).map((e) => SurveyAnswerEntity.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
