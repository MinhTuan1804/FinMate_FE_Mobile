class SurveyOptionEntity {
  final String code;
  final String text;

  const SurveyOptionEntity({required this.code, required this.text});

  factory SurveyOptionEntity.fromJson(Map<String, dynamic> json) =>
      SurveyOptionEntity(code: json['code'] as String, text: json['text'] as String);
}

/// Một câu hỏi khảo sát. [showIf] null = luôn hỏi; không null thì dùng [isVisibleGiven] để tự ẩn/hiện
/// trên máy đúng như BE (xem `ShowIfEvaluator` phía BE) — không cần gọi lại API khi người dùng đổi đáp án.
class SurveyQuestionEntity {
  final String code;
  final String group;
  final String text;
  final Map<String, dynamic>? showIf;
  final List<SurveyOptionEntity> options;

  const SurveyQuestionEntity({
    required this.code,
    required this.group,
    required this.text,
    required this.showIf,
    required this.options,
  });

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
      );
}

class SurveyAnswerEntity {
  final String questionCode;
  final String optionCode;

  const SurveyAnswerEntity({required this.questionCode, required this.optionCode});

  factory SurveyAnswerEntity.fromJson(Map<String, dynamic> json) =>
      SurveyAnswerEntity(questionCode: json['questionCode'] as String, optionCode: json['optionCode'] as String);

  Map<String, dynamic> toJson() => {'questionCode': questionCode, 'optionCode': optionCode};
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
