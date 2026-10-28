import 'package:flutter/material.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';

enum BudgetStatusLevel {
  safe, // < 70%
  warning, // 70% - 89%
  danger, // >= 90%
}

/// Ngân sách tháng: categoryId == null là ngân sách tổng, ngược lại là ngân sách của một danh mục
class BudgetEntity {
  final String id;
  final String? categoryId;
  final String category;
  final BigInt limitAmountCents;
  final BigInt spentAmountCents;
  final int month;
  final int year;

  const BudgetEntity({
    required this.id,
    this.categoryId,
    required this.category,
    required this.limitAmountCents,
    required this.spentAmountCents,
    required this.month,
    required this.year,
  });

  /// Đọc từ GET /budgets (totalBudget hoặc một phần tử của categoryBudgets)
  factory BudgetEntity.fromJson(Map<String, dynamic> json, {required int month, required int year}) {
    return BudgetEntity(
      id: (json['budgetId'] ?? json['id']) as String,
      categoryId: json['categoryId'] as String?,
      category: json['categoryName'] as String? ?? 'Tổng thể',
      limitAmountCents: parseCents(json['limitCents']),
      spentAmountCents: parseCents(json['spentCents']),
      month: month,
      year: year,
    );
  }

  bool get isTotal => categoryId == null;

  /// Tỷ lệ phần trăm chi tiêu hiện tại
  double get spendingPercentage {
    if (limitAmountCents <= BigInt.zero) return 0.0;
    final percentage = (spentAmountCents.toInt() / limitAmountCents.toInt()) * 100.0;
    return double.parse(percentage.toStringAsFixed(1));
  }

  /// Số tiền còn lại trong ngân sách
  BigInt get remainingAmountCents {
    final remaining = limitAmountCents - spentAmountCents;
    return remaining > BigInt.zero ? remaining : BigInt.zero;
  }

  /// Đã chi tiêu vượt quá ngân sách
  bool get isOverspent => spentAmountCents > limitAmountCents;

  /// Phân loại 3 ngưỡng màu sắc theo BR-43
  BudgetStatusLevel get statusLevel {
    if (spendingPercentage >= 90.0) return BudgetStatusLevel.danger;
    if (spendingPercentage >= 70.0) return BudgetStatusLevel.warning;
    return BudgetStatusLevel.safe;
  }

  /// Màu sắc đại diện cho đồng hồ đo ngân sách (BR-43)
  Color get statusColor {
    switch (statusLevel) {
      case BudgetStatusLevel.danger:
        return AppColors.danger;
      case BudgetStatusLevel.warning:
        return AppColors.warning;
      case BudgetStatusLevel.safe:
        return AppColors.safe;
    }
  }

  /// Gợi ý giới hạn chi tiêu an toàn hàng ngày (BR-50): còn lại / số ngày còn lại
  BigInt dailySafeSpendingLimit({required int daysRemaining}) {
    if (daysRemaining <= 0 || limitAmountCents <= spentAmountCents) return BigInt.zero;
    return (limitAmountCents - spentAmountCents) ~/ BigInt.from(daysRemaining);
  }

  String get formattedLimit => formatVnd(limitAmountCents);
  String get formattedSpent => formatVnd(spentAmountCents);
  String get formattedRemaining => formatVnd(remainingAmountCents);
}
