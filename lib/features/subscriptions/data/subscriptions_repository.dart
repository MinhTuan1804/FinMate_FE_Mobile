import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/subscriptions/domain/subscriptions.dart';

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>(
  (ref) => SubscriptionsRepository(apiClient: ref.watch(apiClientProvider)),
);

class SubscriptionsRepository {
  final ApiClient apiClient;

  static const _path = '/api/v1/subscriptions';

  SubscriptionsRepository({required this.apiClient});

  /// Danh sách gói đang bán (chỉ gói active).
  Future<List<SubscriptionPlanEntity>> listPlans() async {
    final response = await apiClient.get(
      '$_path/plans',
      fromJsonT: (json) => (json as List).map((e) => SubscriptionPlanEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Gói hiện tại của user, gói sắp tới, lượt dùng từng chức năng tháng này.
  Future<MySubscriptionEntity> getMine() async {
    final response = await apiClient.get(
      '$_path/me',
      fromJsonT: (json) => MySubscriptionEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Lịch sử đơn mua gói của user (tối đa 50 đơn gần nhất, theo BE).
  Future<List<SubscriptionOrderEntity>> listOrders() async {
    final response = await apiClient.get(
      '$_path/orders',
      fromJsonT: (json) => (json as List).map((e) => SubscriptionOrderEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Liên kết mở trình duyệt để mua/gia hạn gói trên website. [planId] null = để user chọn gói trên web.
  Future<WebSessionLinkEntity> createWebSession({String? planId}) async {
    final response = await apiClient.post(
      '$_path/web-session',
      data: {if (planId != null) 'planId': planId},
      fromJsonT: (json) => WebSessionLinkEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
