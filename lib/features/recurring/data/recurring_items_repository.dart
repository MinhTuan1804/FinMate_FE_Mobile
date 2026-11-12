import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';

final recurringItemsRepositoryProvider = Provider<RecurringItemsRepository>(
  (ref) => RecurringItemsRepository(apiClient: ref.watch(apiClientProvider)),
);

String _dateOnly(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

class RecurringItemsRepository {
  final ApiClient apiClient;

  RecurringItemsRepository({required this.apiClient});

  /// [status] null trả mọi khoản trừ đã hủy và đã từ chối (theo mô tả API)
  Future<List<RecurringItemEntity>> getItems({RecurringStatus? status}) async {
    final response = await apiClient.get(
      '/api/v1/recurring-items',
      queryParameters: status == null ? null : {'status': status.name},
      fromJsonT: (json) => (json as List).map((e) => RecurringItemEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<RecurringItemEntity> createItem({
    required RecurringDirection direction,
    required String name,
    String? counterpartyName,
    required BigInt amountCents,
    required RecurringCadence cadence,
    required DateTime nextDueDate,
    String? categoryId,
    String? financialAccountId,
  }) async {
    final response = await apiClient.post(
      '/api/v1/recurring-items',
      data: {
        'direction': direction.apiValue,
        'name': name,
        if (counterpartyName != null && counterpartyName.isNotEmpty) 'counterpartyName': counterpartyName,
        'amountCents': amountCents.toInt(),
        'cadence': cadence.apiValue,
        'nextDueDate': _dateOnly(nextDueDate),
        if (categoryId != null) 'categoryId': categoryId,
        if (financialAccountId != null) 'financialAccountId': financialAccountId,
      },
      fromJsonT: (json) => RecurringItemEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Trường null giữ nguyên giá trị cũ (theo mô tả API)
  Future<RecurringItemEntity> updateItem({
    required String id,
    String? name,
    BigInt? amountCents,
    RecurringCadence? cadence,
    DateTime? nextDueDate,
    String? categoryId,
    String? financialAccountId,
  }) async {
    final response = await apiClient.patch(
      '/api/v1/recurring-items/$id',
      data: {
        if (name != null) 'name': name,
        if (amountCents != null) 'amountCents': amountCents.toInt(),
        if (cadence != null) 'cadence': cadence.apiValue,
        if (nextDueDate != null) 'nextDueDate': _dateOnly(nextDueDate),
        if (categoryId != null) 'categoryId': categoryId,
        if (financialAccountId != null) 'financialAccountId': financialAccountId,
      },
      fromJsonT: (json) => RecurringItemEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Xác nhận khoản do hệ thống đề xuất (suggested -> active)
  Future<RecurringItemEntity> confirm(String id) async {
    final response = await apiClient.post(
      '/api/v1/recurring-items/$id/confirm',
      fromJsonT: (json) => RecurringItemEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Từ chối đề xuất; hệ thống sẽ không đề xuất lại cùng người nhận (suggested -> rejected)
  Future<RecurringItemEntity> reject(String id) async {
    final response = await apiClient.post(
      '/api/v1/recurring-items/$id/reject',
      fromJsonT: (json) => RecurringItemEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<RecurringItemEntity> pause(String id) async {
    final response = await apiClient.post(
      '/api/v1/recurring-items/$id/pause',
      fromJsonT: (json) => RecurringItemEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<RecurringItemEntity> resume(String id) async {
    final response = await apiClient.post(
      '/api/v1/recurring-items/$id/resume',
      fromJsonT: (json) => RecurringItemEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Hủy khoản (giữ dòng ở trạng thái đã hủy để bộ phát hiện không đề xuất lại)
  Future<void> cancel(String id) => apiClient.delete('/api/v1/recurring-items/$id');
}
