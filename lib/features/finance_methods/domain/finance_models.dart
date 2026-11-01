import 'package:finmate/core/format/money.dart';

/// Mô hình dữ liệu của luồng QUẢN LÝ TÀI CHÍNH: khảo sát -> gợi ý cách quản lý -> áp dụng và chỉnh tham số (T1/T2...).
///
/// Khớp từng trường với JSON thật của backend (`/api/v1/survey`, `/finance-methods`, `/me/methods`, `/me/spendable`);
/// mẫu JSON thật nằm ở `test/fixtures/finance/` để mô hình không lệch khỏi backend.
/// Không có bước xin đồng ý gửi AI: khảo sát nằm ở đầu hành trình, gợi ý chỉ là gợi ý (người dùng không bị buộc áp dụng).

/// Một tham số của phương pháp (vd. ngưỡng T1/T2). Giá trị là số nguyên: `percent` 1-99, `minutes` = số phút từ 00:00, `cents` = đồng, `int` = số đếm.
class ParamDef {
  const ParamDef({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.userEditable,
  });

  final String key;
  final String label;
  final String type;
  final int defaultValue;
  final int min;
  final int max;
  final bool userEditable;

  bool get isPercent => type == 'percent';

  factory ParamDef.fromJson(Map<String, dynamic> json) => ParamDef(
        key: json['key'] as String,
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? 'int',
        defaultValue: (json['default'] as num).toInt(),
        min: (json['min'] as num).toInt(),
        max: (json['max'] as num).toInt(),
        userEditable: json['userEditable'] as bool? ?? false,
      );

  /// Hiển thị một giá trị theo kiểu của tham số ("70%", "22:00", "1.000.000 ₫", "3").
  String format(int value) {
    switch (type) {
      case 'percent':
        return '$value%';
      case 'minutes':
        String two(int n) => n.toString().padLeft(2, '0');
        return '${two(value ~/ 60)}:${two(value % 60)}';
      case 'cents':
        return formatVnd(BigInt.from(value));
      default:
        return '$value';
    }
  }
}

/// Một khối giao diện của trang chủ một cách quản lý. Loại khối do app biết vẽ; admin chọn khối nào, thứ tự nào (backend: `finance_methods.home_layout`).
/// Loại khối app chưa biết (backend mới hơn app) bị bỏ qua khi vẽ chứ không làm hỏng trang.
class HomeBlock {
  const HomeBlock({required this.type, this.title, this.keys, this.display});

  static const spendable = 'spendable';
  static const params = 'params';
  static const jars = 'jars';
  static const goals = 'goals';
  static const starterSteps = 'starter_steps';
  static const displayAllocation = 'allocation';

  final String type;
  final String? title;

  /// Chỉ cho khối `params`: các khóa tham số cần hiện; null = mọi tham số.
  final List<String>? keys;

  /// Chỉ cho khối `params`: `list` (mặc định) hoặc `allocation` (chia phần trăm thu nhập).
  final String? display;

  bool get isAllocation => display == displayAllocation;

  factory HomeBlock.fromJson(Map<String, dynamic> json) => HomeBlock(
        type: json['type'] as String? ?? '',
        title: json['title'] as String?,
        keys: (json['keys'] as List<dynamic>?)?.map((e) => '$e').toList(growable: false),
        display: json['display'] as String?,
      );
}

/// "primary" -> "Cách chính"; "supporting" -> "Cách bổ trợ"; "both" -> "Chính hoặc bổ trợ".
String roleLabel(String role) => switch (role) {
      'primary' => 'Cách chính',
      'supporting' => 'Cách bổ trợ',
      _ => 'Chính hoặc bổ trợ',
    };

class FinanceMethod {
  const FinanceMethod({
    required this.code,
    required this.name,
    required this.summary,
    required this.role,
    required this.goalMode,
    required this.whyText,
    required this.starterSteps,
    required this.params,
    required this.homeLayout,
    this.available = true,
  });

  final String code;
  final String name;
  final String summary;
  final String role; // primary | supporting | both
  final String goalMode;
  final String whyText;
  final List<String> starterSteps;
  final List<ParamDef> params;
  final List<HomeBlock> homeLayout;

  /// false = admin đã ngừng cung cấp cách này. Người đang dùng vẫn dùng như cũ (không mất dữ liệu hay ngưỡng) nhưng app báo và mời chọn cách khác;
  /// danh mục cho người mới chỉ gồm các cách còn cung cấp.
  final bool available;

  bool get canBePrimary => role == 'primary' || role == 'both';
  bool get canBeSupporting => role == 'supporting' || role == 'both';

  factory FinanceMethod.fromJson(Map<String, dynamic> json) => FinanceMethod(
        code: json['code'] as String,
        name: json['name'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        role: json['role'] as String? ?? 'primary',
        goalMode: json['goalMode'] as String? ?? 'track_only',
        whyText: json['whyText'] as String? ?? '',
        starterSteps: (json['starterSteps'] as List<dynamic>? ?? const []).map((e) => '$e').toList(growable: false),
        params: (json['params'] as List<dynamic>? ?? const [])
            .map((e) => ParamDef.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        homeLayout: (json['homeLayout'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(HomeBlock.fromJson)
            .where((block) => block.type.isNotEmpty)
            .toList(growable: false),
        available: json['available'] as bool? ?? true,
      );
}

class RecommendedMethod {
  const RecommendedMethod({required this.method, required this.reason});

  final FinanceMethod method;
  final String reason;

  factory RecommendedMethod.fromJson(Map<String, dynamic> json) => RecommendedMethod(
        method: FinanceMethod.fromJson(json['method'] as Map<String, dynamic>),
        reason: json['reason'] as String? ?? '',
      );
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.primary,
    required this.support,
    required this.source,
    required this.outcome,
  });

  final String id;
  final RecommendedMethod primary;
  final RecommendedMethod? support;
  final String source; // ai | rule_fallback
  final String outcome; // shown | accepted | changed | skipped

  bool get fromAi => source == 'ai';

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        id: json['id'] as String,
        primary: RecommendedMethod.fromJson(json['primary'] as Map<String, dynamic>),
        support: json['support'] == null ? null : RecommendedMethod.fromJson(json['support'] as Map<String, dynamic>),
        source: json['source'] as String? ?? 'rule_fallback',
        outcome: json['outcome'] as String? ?? 'shown',
      );
}

/// Một cách người dùng đang dùng. [effective] là giá trị đang có hiệu lực của MỌI tham số; [overrides] chỉ là phần người dùng đã tự chỉnh.
class UserMethod {
  const UserMethod({
    required this.id,
    required this.method,
    required this.role,
    required this.chosenVia,
    required this.overrides,
    required this.effective,
  });

  final String id;
  final FinanceMethod method;
  final String role; // primary | supporting
  final String chosenVia;
  final Map<String, int> overrides;
  final Map<String, int> effective;

  bool get isPrimary => role == 'primary';

  /// Giá trị đang có hiệu lực của một tham số (ghi đè nếu có, không thì mặc định của phương pháp).
  int valueOf(ParamDef param) => effective[param.key] ?? param.defaultValue;

  factory UserMethod.fromJson(Map<String, dynamic> json) => UserMethod(
        id: json['id'] as String,
        method: FinanceMethod.fromJson(json['method'] as Map<String, dynamic>),
        role: json['role'] as String? ?? 'primary',
        chosenVia: json['chosenVia'] as String? ?? '',
        overrides: _intMap(json['overrides']),
        effective: _intMap(json['effective']),
      );
}

Map<String, int> _intMap(Object? raw) => {
      for (final entry in (raw as Map<String, dynamic>? ?? const <String, dynamic>{}).entries) entry.key: (entry.value as num).toInt(),
    };

class SurveyOption {
  const SurveyOption({required this.code, required this.text});

  final String code;
  final String text;

  factory SurveyOption.fromJson(Map<String, dynamic> json) =>
      SurveyOption(code: json['code'] as String, text: json['text'] as String? ?? '');
}

class SurveyQuestion {
  const SurveyQuestion({required this.code, required this.group, required this.text, required this.showIf, required this.options});

  final String code;
  final String group;
  final String text;

  /// `{"all":[{"question":mã,"in":[mã đáp án]} | {"question":mã,"not_in":[mã đáp án]}]}`; null = luôn hỏi.
  final Map<String, dynamic>? showIf;
  final List<SurveyOption> options;

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
        code: json['code'] as String,
        group: json['group'] as String? ?? '',
        text: json['text'] as String? ?? '',
        showIf: json['showIf'] as Map<String, dynamic>?,
        options: (json['options'] as List<dynamic>? ?? const [])
            .map((e) => SurveyOption.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class SurveyAnswer {
  const SurveyAnswer(this.questionCode, this.optionCode);

  final String questionCode;
  final String optionCode;

  Map<String, String> toJson() => {'questionCode': questionCode, 'optionCode': optionCode};

  factory SurveyAnswer.fromJson(Map<String, dynamic> json) => SurveyAnswer(json['questionCode'] as String, json['optionCode'] as String);
}

class Survey {
  const Survey({required this.status, required this.questions, required this.answers});

  final String status; // pending | completed | skipped
  final List<SurveyQuestion> questions;
  final List<SurveyAnswer> answers;

  bool get isCompleted => status == 'completed' && answers.isNotEmpty;

  factory Survey.fromJson(Map<String, dynamic> json) => Survey(
        status: json['status'] as String? ?? 'pending',
        questions: (json['questions'] as List<dynamic>? ?? const [])
            .map((e) => SurveyQuestion.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        answers: (json['answers'] as List<dynamic>? ?? const [])
            .map((e) => SurveyAnswer.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// Một điều kiện hiển thị đúng với các câu trả lời hiện có? Cùng quy tắc với backend (`ShowIfEvaluator`): câu chưa trả lời không nằm trong
/// danh sách nào nên `in` sai, `not_in` đúng; cấu hình hỏng hoặc null thì HIỆN câu (lỗi cấu hình không được làm mất một câu khảo sát).
bool showIfHolds(Map<String, dynamic>? showIf, Map<String, String> answers) {
  if (showIf == null) return true;
  final all = showIf['all'];
  if (all is! List) return true;
  for (final condition in all) {
    if (condition is! Map<String, dynamic>) return true;
    final question = condition['question'];
    if (question is! String) return true;
    final answered = answers[question];
    if (condition['in'] is List) {
      if (answered == null || !(condition['in'] as List).contains(answered)) return false;
    } else if (condition['not_in'] is List) {
      if (answered != null && (condition['not_in'] as List).contains(answered)) return false;
    } else {
      return true;
    }
  }
  return true;
}

/// Các câu ĐANG hiển thị theo thứ tự, tính lần lượt: câu ẩn không đưa câu trả lời cũ của nó vào điều kiện của câu sau.
List<SurveyQuestion> visibleQuestions(List<SurveyQuestion> questions, Map<String, String> answers) {
  final visible = <SurveyQuestion>[];
  final effective = <String, String>{};
  for (final question in questions) {
    if (!showIfHolds(question.showIf, effective)) continue;
    visible.add(question);
    final answer = answers[question.code];
    if (answer != null) effective[question.code] = answer;
  }
  return visible;
}

/// Một mục tiêu đang được dành tiền trong tháng (`/me/spendable`).
class SpendableGoal {
  const SpendableGoal({
    required this.goalId,
    required this.name,
    required this.requiredPerMonthCents,
    required this.depositedThisMonthCents,
    required this.setAsideCents,
  });

  final String goalId;
  final String name;
  final int requiredPerMonthCents;
  final int depositedThisMonthCents;
  final int setAsideCents;

  factory SpendableGoal.fromJson(Map<String, dynamic> json) => SpendableGoal(
        goalId: json['goalId'] as String,
        name: json['name'] as String? ?? '',
        requiredPerMonthCents: (json['requiredPerMonthCents'] as num? ?? 0).toInt(),
        depositedThisMonthCents: (json['depositedThisMonthCents'] as num? ?? 0).toInt(),
        setAsideCents: (json['setAsideCents'] as num? ?? 0).toInt(),
      );
}

/// "Tiền khả dụng" của tháng, backend tính một chỗ. [incomeCents] và [spendableCents] là null khi người dùng chưa khai thu nhập ("chưa biết", không phải 0).
class SpendableInfo {
  const SpendableInfo({
    required this.goalMode,
    required this.incomeCents,
    required this.spentCents,
    required this.goalSetAsideCents,
    required this.spendableCents,
    required this.goals,
  });

  final String? goalMode;
  final int? incomeCents;
  final int spentCents;
  final int goalSetAsideCents;
  final int? spendableCents;
  final List<SpendableGoal> goals;

  /// Mục tiêu chưa khả thi: số cần dành mỗi tháng để kịp hạn đã lớn hơn cả thu nhập (nạp bao nhiêu trong tháng cũng không đổi điều đó).
  /// Chỉ xét được khi đã khai thu nhập.
  List<SpendableGoal> get unaffordableGoals {
    final income = incomeCents;
    if (income == null) return const [];
    return goals.where((g) => g.requiredPerMonthCents > income).toList(growable: false);
  }

  /// Số được chi không tính các mục tiêu chưa khả thi (nếu tính thì số luôn âm theo một mục tiêu không thể đạt, người dùng không biết làm gì).
  /// Bằng [spendableCents] khi mọi mục tiêu đều khả thi; null khi chưa khai thu nhập.
  int? get spendableWithoutUnaffordableCents {
    final amount = spendableCents;
    if (amount == null) return null;
    return amount + unaffordableGoals.fold<int>(0, (sum, g) => sum + g.setAsideCents);
  }

  factory SpendableInfo.fromJson(Map<String, dynamic> json) => SpendableInfo(
        goalMode: json['goalMode'] as String?,
        incomeCents: (json['incomeCents'] as num?)?.toInt(),
        spentCents: (json['spentCents'] as num? ?? 0).toInt(),
        goalSetAsideCents: (json['goalSetAsideCents'] as num? ?? 0).toInt(),
        spendableCents: (json['spendableCents'] as num?)?.toInt(),
        goals: (json['goals'] as List<dynamic>? ?? const [])
            .map((e) => SpendableGoal.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// Mẫu mục tiêu gợi ý theo cách đang dùng (`/me/goal-suggestions`).
class GoalSuggestion {
  const GoalSuggestion({required this.templateCode, required this.name, required this.description, required this.methodCode});

  final String templateCode;
  final String name;
  final String description;
  final String methodCode;

  factory GoalSuggestion.fromJson(Map<String, dynamic> json) => GoalSuggestion(
        templateCode: json['templateCode'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        methodCode: json['methodCode'] as String? ?? '',
      );
}

class JarCategory {
  const JarCategory({required this.slug, required this.name});

  final String slug;
  final String name;

  factory JarCategory.fromJson(Map<String, dynamic> json) => JarCategory(slug: json['slug'] as String, name: json['name'] as String? ?? '');
}

/// Một hũ: phần thu nhập được chia, đã chi tháng này (theo danh mục thuộc hũ) và mức so với ngưỡng cảnh báo của chính người dùng.
class Jar {
  const Jar({
    required this.key,
    required this.label,
    required this.allocationPct,
    required this.allocatedCents,
    required this.spentCents,
    required this.remainingCents,
    required this.usedPct,
    required this.level,
    required this.categories,
  });

  static const levelNone = 'none';
  static const levelOk = 'ok';
  static const levelT1 = 't1';
  static const levelT2 = 't2';
  static const levelOver = 'over';

  final String key;
  final String label;
  final int allocationPct;

  /// null khi người dùng chưa khai thu nhập ("chưa biết", không phải 0): khi đó chỉ hiện số đã chi.
  final int? allocatedCents;
  final int spentCents;
  final int? remainingCents;
  final int? usedPct;

  /// `none` (không có số được chia), `ok`, `t1` (chạm nhắc nhẹ), `t2` (chạm cảnh báo mạnh), `over` (vượt hũ).
  final String level;
  final List<JarCategory> categories;

  factory Jar.fromJson(Map<String, dynamic> json) => Jar(
        key: json['key'] as String,
        label: json['label'] as String? ?? '',
        allocationPct: (json['allocationPct'] as num).toInt(),
        allocatedCents: (json['allocatedCents'] as num?)?.toInt(),
        spentCents: (json['spentCents'] as num? ?? 0).toInt(),
        remainingCents: (json['remainingCents'] as num?)?.toInt(),
        usedPct: (json['usedPct'] as num?)?.toInt(),
        level: json['level'] as String? ?? levelNone,
        categories: (json['categories'] as List<dynamic>? ?? const []).map((e) => JarCategory.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      );
}

/// Các hũ của MỘT cách quản lý người dùng đang dùng, cho tháng hiện tại (`/me/jars`).
class JarSet {
  const JarSet({
    required this.userMethodId,
    required this.methodCode,
    required this.title,
    required this.incomeCents,
    required this.jars,
    required this.unassignedSpentCents,
  });

  final String userMethodId;
  final String methodCode;
  final String? title;
  final int? incomeCents;
  final List<Jar> jars;

  /// Chi tiêu tháng này nằm ngoài mọi hũ (danh mục chưa gán vào hũ, danh mục riêng, chưa phân loại).
  final int unassignedSpentCents;

  factory JarSet.fromJson(Map<String, dynamic> json) => JarSet(
        userMethodId: json['userMethodId'] as String,
        methodCode: json['methodCode'] as String? ?? '',
        title: json['title'] as String?,
        incomeCents: (json['incomeCents'] as num?)?.toInt(),
        jars: (json['jars'] as List<dynamic>? ?? const []).map((e) => Jar.fromJson(e as Map<String, dynamic>)).toList(growable: false),
        unassignedSpentCents: (json['unassignedSpentCents'] as num? ?? 0).toInt(),
      );
}

/// Một cặp ngưỡng cảnh báo ngân sách (% hạn mức đã dùng): [t1] nhắc nhẹ, [t2] cảnh báo mạnh. Mức "vượt hạn mức" luôn là 100%.
class ThresholdPair {
  const ThresholdPair(this.t1, this.t2);

  final int t1;
  final int t2;

  factory ThresholdPair.fromJson(Map<String, dynamic> json) => ThresholdPair((json['t1Pct'] as num).toInt(), (json['t2Pct'] as num).toInt());

  /// Cùng quy tắc với backend (`AlertThresholds.IsValid`): 1 ≤ T1 < T2 ≤ 99.
  static bool isValid(int t1, int t2) => t1 >= 1 && t1 < t2 && t2 <= 99;

  @override
  bool operator ==(Object other) => other is ThresholdPair && other.t1 == t1 && other.t2 == t2;

  @override
  int get hashCode => Object.hash(t1, t2);
}

/// Ngưỡng cảnh báo đang áp dụng cho người dùng và nguồn của nó (`/me/alert-thresholds`).
/// Thứ tự: cách quản lý đang dùng có T1/T2 → ngưỡng cá nhân → mặc định hệ thống do admin đặt.
class AlertThresholdSettings {
  const AlertThresholdSettings({
    required this.effective,
    required this.source,
    required this.methodCode,
    required this.methodName,
    required this.personal,
    required this.systemDefault,
  });

  static const sourceMethod = 'method';
  static const sourcePersonal = 'personal';
  static const sourceSystem = 'system';

  /// Ngưỡng đang thật sự có hiệu lực.
  final ThresholdPair effective;

  /// `method`, `personal` hoặc `system`.
  final String source;
  final String? methodCode;
  final String? methodName;

  /// Ngưỡng cá nhân đã lưu; có thể đang bị cách quản lý che (vẫn được giữ, dùng lại khi ngừng cách đó).
  final ThresholdPair? personal;
  final ThresholdPair systemDefault;

  bool get followsMethod => source == sourceMethod;

  factory AlertThresholdSettings.fromJson(Map<String, dynamic> json) => AlertThresholdSettings(
        effective: ThresholdPair((json['t1Pct'] as num).toInt(), (json['t2Pct'] as num).toInt()),
        source: json['source'] as String? ?? sourceSystem,
        methodCode: json['methodCode'] as String?,
        methodName: json['methodName'] as String?,
        personal: json['personal'] == null ? null : ThresholdPair.fromJson(json['personal'] as Map<String, dynamic>),
        systemDefault: ThresholdPair.fromJson(json['systemDefault'] as Map<String, dynamic>),
      );
}
