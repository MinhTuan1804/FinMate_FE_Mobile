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
