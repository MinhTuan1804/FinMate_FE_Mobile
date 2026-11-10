import 'package:finmate/core/format/money.dart';

/// Một tham số của phương pháp (vd t1_pct, needs_pct). [type]: 'percent' | 'int' | 'cents' | 'minutes' (nguyên văn BE, chỉ dùng để chọn widget nhập phù hợp).
class ParamEntity {
  final String key;
  final String label;
  final String type;
  final int defaultValue;
  final int min;
  final int max;
  final bool userEditable;

  const ParamEntity({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.userEditable,
  });

  factory ParamEntity.fromJson(Map<String, dynamic> json) => ParamEntity(
        key: json['key'] as String,
        label: json['label'] as String,
        type: json['type'] as String,
        defaultValue: (json['default'] as num).toInt(),
        min: (json['min'] as num).toInt(),
        max: (json['max'] as num).toInt(),
        userEditable: json['userEditable'] as bool,
      );
}

/// Một cách quản lý tài chính trong catalog. [role]: 'primary'|'supporting'|'both'.
/// [goalMode]: 'reserve_first'|'envelope'|'available_to_spend'|'track_only' (nguyên văn BE, snake_case).
class MethodEntity {
  final String code;
  final String name;
  final String summary;
  final String role;
  final String goalMode;
  final String whyText;
  final List<String> starterSteps;
  final List<ParamEntity> params;
  final bool available;

  const MethodEntity({
    required this.code,
    required this.name,
    required this.summary,
    required this.role,
    required this.goalMode,
    required this.whyText,
    required this.starterSteps,
    required this.params,
    required this.available,
  });

  bool get canBePrimary => role == 'primary' || role == 'both';
  bool get canBeSupport => role == 'supporting' || role == 'both';

  factory MethodEntity.fromJson(Map<String, dynamic> json) => MethodEntity(
        code: json['code'] as String,
        name: json['name'] as String,
        summary: json['summary'] as String,
        role: json['role'] as String,
        goalMode: json['goalMode'] as String,
        whyText: json['whyText'] as String,
        starterSteps: (json['starterSteps'] as List).map((e) => e as String).toList(),
        params: (json['params'] as List).map((e) => ParamEntity.fromJson(e as Map<String, dynamic>)).toList(),
        available: json['available'] as bool? ?? true,
      );
}

class RecommendedMethodEntity {
  final MethodEntity method;
  final String reason;

  const RecommendedMethodEntity({required this.method, required this.reason});

  factory RecommendedMethodEntity.fromJson(Map<String, dynamic> json) => RecommendedMethodEntity(
        method: MethodEntity.fromJson(json['method'] as Map<String, dynamic>),
        reason: json['reason'] as String,
      );
}

/// [source]: 'ai'|'rule_fallback'. [outcome]: 'shown'|'accepted'|'changed'|'skipped'.
class RecommendationEntity {
  final String id;
  final RecommendedMethodEntity primary;
  final RecommendedMethodEntity? support;
  final String source;
  final String outcome;
  final DateTime createdAt;

  const RecommendationEntity({
    required this.id,
    required this.primary,
    this.support,
    required this.source,
    required this.outcome,
    required this.createdAt,
  });

  bool get isDecided => outcome != 'shown';

  factory RecommendationEntity.fromJson(Map<String, dynamic> json) => RecommendationEntity(
        id: json['id'] as String,
        primary: RecommendedMethodEntity.fromJson(json['primary'] as Map<String, dynamic>),
        support: json['support'] == null ? null : RecommendedMethodEntity.fromJson(json['support'] as Map<String, dynamic>),
        source: json['source'] as String,
        outcome: json['outcome'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

/// Một phương pháp NGƯỜI DÙNG đang dùng. [role]: 'primary'|'supporting'. [chosenVia]: 'recommended'|'manual'.
class UserMethodEntity {
  final String id;
  final MethodEntity method;
  final String role;
  final String chosenVia;
  final Map<String, int> overrides;
  final Map<String, int> effective;
  final DateTime startedAt;

  const UserMethodEntity({
    required this.id,
    required this.method,
    required this.role,
    required this.chosenVia,
    required this.overrides,
    required this.effective,
    required this.startedAt,
  });

  bool get isPrimary => role == 'primary';

  factory UserMethodEntity.fromJson(Map<String, dynamic> json) => UserMethodEntity(
        id: json['id'] as String,
        method: MethodEntity.fromJson(json['method'] as Map<String, dynamic>),
        role: json['role'] as String,
        chosenVia: json['chosenVia'] as String,
        overrides: (json['overrides'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        effective: (json['effective'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
      );
}

class GoalSuggestionEntity {
  final String templateCode;
  final String name;
  final String description;
  final String methodCode;

  const GoalSuggestionEntity({
    required this.templateCode,
    required this.name,
    required this.description,
    required this.methodCode,
  });

  factory GoalSuggestionEntity.fromJson(Map<String, dynamic> json) => GoalSuggestionEntity(
        templateCode: json['templateCode'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        methodCode: json['methodCode'] as String,
      );
}

class SpendableGoalEntity {
  final String goalId;
  final String name;
  final BigInt requiredPerMonthCents;
  final BigInt depositedThisMonthCents;
  final BigInt setAsideCents;

  const SpendableGoalEntity({
    required this.goalId,
    required this.name,
    required this.requiredPerMonthCents,
    required this.depositedThisMonthCents,
    required this.setAsideCents,
  });

  factory SpendableGoalEntity.fromJson(Map<String, dynamic> json) => SpendableGoalEntity(
        goalId: json['goalId'] as String,
        name: json['name'] as String,
        requiredPerMonthCents: parseCents(json['requiredPerMonthCents']),
        depositedThisMonthCents: parseCents(json['depositedThisMonthCents']),
        setAsideCents: parseCents(json['setAsideCents']),
      );
}

/// "Tiền khả dụng" của tháng này. [incomeCents]/[spendableCents] null = chưa khai thu nhập ("chưa biết", không phải 0).
class SpendableEntity {
  final String? goalMode;
  final BigInt? incomeCents;
  final BigInt spentCents;
  final BigInt goalSetAsideCents;
  final BigInt? spendableCents;
  final List<SpendableGoalEntity> goals;

  const SpendableEntity({
    required this.goalMode,
    required this.incomeCents,
    required this.spentCents,
    required this.goalSetAsideCents,
    required this.spendableCents,
    required this.goals,
  });

  factory SpendableEntity.fromJson(Map<String, dynamic> json) => SpendableEntity(
        goalMode: json['goalMode'] as String?,
        incomeCents: json['incomeCents'] == null ? null : parseCents(json['incomeCents']),
        spentCents: parseCents(json['spentCents']),
        goalSetAsideCents: parseCents(json['goalSetAsideCents']),
        spendableCents: json['spendableCents'] == null ? null : parseCents(json['spendableCents']),
        goals: (json['goals'] as List).map((e) => SpendableGoalEntity.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class JarCategoryEntity {
  final String slug;
  final String name;

  const JarCategoryEntity({required this.slug, required this.name});

  factory JarCategoryEntity.fromJson(Map<String, dynamic> json) =>
      JarCategoryEntity(slug: json['slug'] as String, name: json['name'] as String);
}

/// [level]: 'none'|'ok'|'t1'|'t2'|'over' — so với ngưỡng cảnh báo của chính người dùng.
class JarEntity {
  final String key;
  final String label;
  final int allocationPct;
  final BigInt? allocatedCents;
  final BigInt spentCents;
  final BigInt? remainingCents;
  final int? usedPct;
  final String level;
  final List<JarCategoryEntity> categories;

  const JarEntity({
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

  factory JarEntity.fromJson(Map<String, dynamic> json) => JarEntity(
        key: json['key'] as String,
        label: json['label'] as String,
        allocationPct: json['allocationPct'] as int,
        allocatedCents: json['allocatedCents'] == null ? null : parseCents(json['allocatedCents']),
        spentCents: parseCents(json['spentCents']),
        remainingCents: json['remainingCents'] == null ? null : parseCents(json['remainingCents']),
        usedPct: json['usedPct'] as int?,
        level: json['level'] as String,
        categories: (json['categories'] as List).map((e) => JarCategoryEntity.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class JarSetEntity {
  final String userMethodId;
  final String methodCode;
  final String methodName;
  final String? title;
  final DateTime periodStart;
  final DateTime periodEnd;
  final BigInt? incomeCents;
  final List<JarEntity> jars;
  final BigInt unassignedSpentCents;
  final int t1Pct;
  final int t2Pct;

  const JarSetEntity({
    required this.userMethodId,
    required this.methodCode,
    required this.methodName,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    required this.incomeCents,
    required this.jars,
    required this.unassignedSpentCents,
    required this.t1Pct,
    required this.t2Pct,
  });

  factory JarSetEntity.fromJson(Map<String, dynamic> json) => JarSetEntity(
        userMethodId: json['userMethodId'] as String,
        methodCode: json['methodCode'] as String,
        methodName: json['methodName'] as String,
        title: json['title'] as String?,
        // PeriodStart/PeriodEnd là mốc đầu/cuối tháng theo giờ Việt Nam, không phải "khoảnh khắc" cần đổi múi giờ hiển thị
        periodStart: DateTime.parse(json['periodStart'] as String),
        periodEnd: DateTime.parse(json['periodEnd'] as String),
        incomeCents: json['incomeCents'] == null ? null : parseCents(json['incomeCents']),
        jars: (json['jars'] as List).map((e) => JarEntity.fromJson(e as Map<String, dynamic>)).toList(),
        unassignedSpentCents: parseCents(json['unassignedSpentCents']),
        t1Pct: json['t1Pct'] as int,
        t2Pct: json['t2Pct'] as int,
      );
}

class ThresholdPairEntity {
  final int t1Pct;
  final int t2Pct;

  const ThresholdPairEntity({required this.t1Pct, required this.t2Pct});

  factory ThresholdPairEntity.fromJson(Map<String, dynamic> json) =>
      ThresholdPairEntity(t1Pct: json['t1Pct'] as int, t2Pct: json['t2Pct'] as int);
}

/// [source]: 'method' (theo cách quản lý đang dùng) | 'personal' (ngưỡng cá nhân) | 'system' (mặc định hệ thống).
class AlertThresholdSettingsEntity {
  final int t1Pct;
  final int t2Pct;
  final String source;
  final String? methodCode;
  final String? methodName;
  final ThresholdPairEntity? personal;
  final ThresholdPairEntity systemDefault;

  const AlertThresholdSettingsEntity({
    required this.t1Pct,
    required this.t2Pct,
    required this.source,
    required this.methodCode,
    required this.methodName,
    required this.personal,
    required this.systemDefault,
  });

  factory AlertThresholdSettingsEntity.fromJson(Map<String, dynamic> json) => AlertThresholdSettingsEntity(
        t1Pct: json['t1Pct'] as int,
        t2Pct: json['t2Pct'] as int,
        source: json['source'] as String,
        methodCode: json['methodCode'] as String?,
        methodName: json['methodName'] as String?,
        personal: json['personal'] == null ? null : ThresholdPairEntity.fromJson(json['personal'] as Map<String, dynamic>),
        systemDefault: ThresholdPairEntity.fromJson(json['systemDefault'] as Map<String, dynamic>),
      );
}
