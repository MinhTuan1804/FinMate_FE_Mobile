import 'package:flutter/material.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';

/// Mục tiêu tiết kiệm (GET /saving-goals)
class SavingsGoalEntity {
  final String id;
  final String title;
  final BigInt targetAmountCents;
  final BigInt currentAmountCents;
  final DateTime? targetDate;
  final String status;

  const SavingsGoalEntity({
    required this.id,
    required this.title,
    required this.targetAmountCents,
    required this.currentAmountCents,
    this.targetDate,
    this.status = 'active',
  });

  factory SavingsGoalEntity.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'] as String?;
    return SavingsGoalEntity(
      id: json['id'] as String,
      title: json['name'] as String? ?? '',
      targetAmountCents: parseCents(json['targetCents']),
      currentAmountCents: parseCents(json['savedCents']),
      targetDate: deadline == null ? null : DateTime.tryParse(deadline)?.toLocal(),
      status: (json['status'] as String? ?? 'active').toLowerCase(),
    );
  }

  /// Tỷ lệ phần trăm đã tiết kiệm được
  double get progressPercentage {
    if (targetAmountCents <= BigInt.zero) return 0.0;
    final percentage = (currentAmountCents.toInt() / targetAmountCents.toInt()) * 100.0;
    return double.parse(percentage.toStringAsFixed(1));
  }

  bool get isCompleted => status == 'completed' || (targetAmountCents > BigInt.zero && currentAmountCents >= targetAmountCents);

  bool isOverdue({DateTime? asOf}) => !isCompleted && targetDate != null && targetDate!.isBefore(asOf ?? DateTime.now());

  /// Số tiền cần nạp mỗi tháng để kịp hạn chót (làm tròn lên, tối thiểu 1 tháng);
  /// null nếu không có hạn chót, đã hoàn thành hoặc đã trễ hạn.
  BigInt? requiredPerMonth({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final deadline = targetDate;
    if (deadline == null || isCompleted || isOverdue(asOf: now)) return null;

    final months = ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(1, 1200);
    final remaining = targetAmountCents - currentAmountCents;
    return (remaining + BigInt.from(months - 1)) ~/ BigInt.from(months);
  }

  String statusLabel({DateTime? asOf}) {
    if (isCompleted) return 'Hoàn thành';
    if (isOverdue(asOf: asOf)) return 'Trễ hạn';
    final perMonth = requiredPerMonth(asOf: asOf);
    if (perMonth == null) return 'Không hạn chót';
    return 'Cần ~${formatVnd(perMonth)}/tháng';
  }

  Color statusColor({DateTime? asOf}) {
    if (isCompleted) return AppColors.safe;
    if (isOverdue(asOf: asOf)) return AppColors.danger;
    return AppColors.primary;
  }

  String get formattedTarget => formatVnd(targetAmountCents);
  String get formattedCurrent => formatVnd(currentAmountCents);
}

/// Cảnh báo kèm gợi ý về tính khả thi của mục tiêu (không phải từ chối) — dùng chung cho
/// cả tiến độ mục tiêu đã có (GoalProgressEntity.feasibility) và bản xem trước mục tiêu chưa tạo.
class GoalFeasibilityEntity {
  final BigInt requiredPerMonthCents;
  final BigInt? availablePerMonthCents;
  final bool? isFeasible;
  final DateTime? suggestedDeadline;
  final BigInt? suggestedTargetCents;

  const GoalFeasibilityEntity({
    required this.requiredPerMonthCents,
    this.availablePerMonthCents,
    this.isFeasible,
    this.suggestedDeadline,
    this.suggestedTargetCents,
  });

  factory GoalFeasibilityEntity.fromJson(Map<String, dynamic> json) => GoalFeasibilityEntity(
        requiredPerMonthCents: parseCents(json['requiredPerMonthCents']),
        availablePerMonthCents: json['availablePerMonthCents'] == null ? null : parseCents(json['availablePerMonthCents']),
        isFeasible: json['isFeasible'] as bool?,
        suggestedDeadline: (json['suggestedDeadline'] as String?) == null ? null : DateTime.tryParse(json['suggestedDeadline'] as String)?.toLocal(),
        suggestedTargetCents: json['suggestedTargetCents'] == null ? null : parseCents(json['suggestedTargetCents']),
      );

  String get formattedRequiredPerMonth => formatVnd(requiredPerMonthCents);
}

/// Một lần nạp tiền vào mục tiêu (trong GoalProgressEntity.recentContributions)
class GoalContributionEntity {
  final String id;
  final BigInt amountCents;
  final String? note;
  final DateTime contributedAt;

  const GoalContributionEntity({required this.id, required this.amountCents, this.note, required this.contributedAt});

  factory GoalContributionEntity.fromJson(Map<String, dynamic> json) => GoalContributionEntity(
        id: json['id'] as String,
        amountCents: parseCents(json['amountCents']),
        note: json['note'] as String?,
        contributedAt: DateTime.parse(json['contributedAt'] as String).toLocal(),
      );

  String get formattedAmount => formatVnd(amountCents);
}

/// Tiến độ chi tiết của một mục tiêu (GET /saving-goals/{id}/progress)
class GoalProgressEntity {
  final String goalId;
  final String name;
  final String status;
  final BigInt targetCents;
  final BigInt savedCents;
  final BigInt remainingCents;
  final int percentComplete;
  final DateTime? deadline;
  final int? daysRemaining;
  final BigInt? requiredPerDayCents;
  final bool isOnTrack;
  final List<GoalContributionEntity> recentContributions;
  final GoalFeasibilityEntity? feasibility;

  const GoalProgressEntity({
    required this.goalId,
    required this.name,
    required this.status,
    required this.targetCents,
    required this.savedCents,
    required this.remainingCents,
    required this.percentComplete,
    this.deadline,
    this.daysRemaining,
    this.requiredPerDayCents,
    required this.isOnTrack,
    this.recentContributions = const [],
    this.feasibility,
  });

  factory GoalProgressEntity.fromJson(Map<String, dynamic> json) => GoalProgressEntity(
        goalId: json['goalId'] as String,
        name: json['name'] as String? ?? '',
        status: (json['status'] as String? ?? 'active').toLowerCase(),
        targetCents: parseCents(json['targetCents']),
        savedCents: parseCents(json['savedCents']),
        remainingCents: parseCents(json['remainingCents']),
        percentComplete: json['percentComplete'] as int? ?? 0,
        deadline: (json['deadline'] as String?) == null ? null : DateTime.tryParse(json['deadline'] as String)?.toLocal(),
        daysRemaining: json['daysRemaining'] as int?,
        requiredPerDayCents: json['requiredPerDayCents'] == null ? null : parseCents(json['requiredPerDayCents']),
        isOnTrack: json['isOnTrack'] as bool? ?? true,
        recentContributions: (json['recentContributions'] as List<dynamic>? ?? const [])
            .map((e) => GoalContributionEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        feasibility: json['feasibility'] == null ? null : GoalFeasibilityEntity.fromJson(json['feasibility'] as Map<String, dynamic>),
      );

  String get formattedTarget => formatVnd(targetCents);
  String get formattedSaved => formatVnd(savedCents);
  String get formattedRemaining => formatVnd(remainingCents);
}
