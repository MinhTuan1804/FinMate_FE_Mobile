import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';

final planningRepositoryProvider = Provider<PlanningRepository>(
  (ref) => PlanningRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Ngân sách và mục tiêu tiết kiệm. Không có dữ liệu mẫu: lỗi được ném lại cho màn hình.
class PlanningRepository {
  final ApiClient apiClient;

  PlanningRepository({required this.apiClient});

  Future<({BudgetEntity? total, List<BudgetEntity> categories})> getBudgets({required int month, required int year}) async {
    final response = await apiClient.get(
      '/api/v1/budgets',
      queryParameters: {'year': year, 'month': month},
      fromJsonT: (json) => json as Map<String, dynamic>,
    );
    final data = response.data ?? const <String, dynamic>{};

    final totalJson = data['totalBudget'];
    return (
      total: totalJson is Map<String, dynamic> ? BudgetEntity.fromJson(totalJson, month: month, year: year) : null,
      categories: ((data['categoryBudgets'] as List?) ?? const [])
          .map((e) => BudgetEntity.fromJson(e as Map<String, dynamic>, month: month, year: year))
          .toList(),
    );
  }

  /// categoryId == null: ngân sách tổng của tháng
  Future<void> createBudget({String? categoryId, required BigInt limitCents}) async {
    await apiClient.post(
      '/api/v1/budgets',
      data: {
        if (categoryId != null) 'categoryId': categoryId,
        'limitCents': limitCents.toInt(),
      },
      fromJsonT: (json) => json,
    );
  }

  Future<void> updateBudgetLimit(String id, BigInt limitCents) async {
    await apiClient.patch(
      '/api/v1/budgets/$id',
      data: {'limitCents': limitCents.toInt()},
      fromJsonT: (json) => json,
    );
  }

  /// Chuyển một phần hạn mức từ ngân sách này sang ngân sách khác (cùng tháng)
  Future<void> transferBudgetLimit({required String fromBudgetId, required String toBudgetId, required BigInt amountCents}) async {
    await apiClient.post(
      '/api/v1/budgets/transfer',
      data: {
        'fromBudgetId': fromBudgetId,
        'toBudgetId': toBudgetId,
        'amountCents': amountCents.toInt(),
      },
      fromJsonT: (json) => json,
    );
  }

  Future<void> deleteBudget(String id) => apiClient.delete('/api/v1/budgets/$id');

  Future<List<SavingsGoalEntity>> getGoals() async {
    final response = await apiClient.get(
      '/api/v1/saving-goals',
      fromJsonT: (json) => (json as List).map((e) => SavingsGoalEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<void> createGoal({required String name, required BigInt targetCents, DateTime? deadline}) async {
    await apiClient.post(
      '/api/v1/saving-goals',
      data: {
        'name': name,
        'targetCents': targetCents.toInt(),
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
      },
      fromJsonT: (json) => json,
    );
  }

  /// Nạp tiền vào mục tiêu; backend còn trả `celebration` (cấp độ/vật phẩm) nhưng FE không dùng
  Future<SavingsGoalEntity> contribute(String goalId, BigInt amountCents, {String? note}) async {
    final response = await apiClient.post(
      '/api/v1/saving-goals/$goalId/contribute',
      data: {
        'amountCents': amountCents.toInt(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
      fromJsonT: (json) => SavingsGoalEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Sửa tên/hạn mức/hạn chót của mục tiêu
  Future<SavingsGoalEntity> updateGoal({required String id, required String name, required BigInt targetCents, DateTime? deadline}) async {
    final response = await apiClient.patch(
      '/api/v1/saving-goals/$id',
      data: {
        'name': name,
        'targetCents': targetCents.toInt(),
        'deadline': deadline?.toUtc().toIso8601String(),
      },
      fromJsonT: (json) => SavingsGoalEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Hủy một mục tiêu đang theo đuổi (không xóa, chỉ chuyển trạng thái)
  Future<SavingsGoalEntity> cancelGoal(String id) async {
    final response = await apiClient.post(
      '/api/v1/saving-goals/$id/cancel',
      fromJsonT: (json) => SavingsGoalEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Tiến độ chi tiết (số ngày còn lại, cần nạp bao nhiêu/ngày, lịch sử nạp gần đây, tính khả thi)
  Future<GoalProgressEntity> getGoalProgress(String id) async {
    final response = await apiClient.get(
      '/api/v1/saving-goals/$id/progress',
      fromJsonT: (json) => GoalProgressEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Xem trước tính khả thi cho một mục tiêu CHƯA tạo (cùng công thức với tiến độ mục tiêu đã có).
  /// null khi không còn gì phải góp (đã đủ tiền).
  Future<GoalFeasibilityEntity?> previewFeasibility({required BigInt targetCents, BigInt? savedCents, required DateTime deadline}) async {
    final response = await apiClient.post(
      '/api/v1/saving-goals/feasibility',
      data: {
        'targetCents': targetCents.toInt(),
        'savedCents': (savedCents ?? BigInt.zero).toInt(),
        'deadline': deadline.toUtc().toIso8601String(),
      },
      fromJsonT: (json) => GoalFeasibilityEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }
}
