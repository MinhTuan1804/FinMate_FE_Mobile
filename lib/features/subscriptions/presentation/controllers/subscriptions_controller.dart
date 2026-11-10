import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/subscriptions/data/subscriptions_repository.dart';
import 'package:finmate/features/subscriptions/domain/subscriptions.dart';

final subscriptionPlansProvider = FutureProvider.autoDispose<List<SubscriptionPlanEntity>>(
  (ref) => ref.watch(subscriptionsRepositoryProvider).listPlans(),
);

final mySubscriptionProvider = FutureProvider.autoDispose<MySubscriptionEntity>(
  (ref) => ref.watch(subscriptionsRepositoryProvider).getMine(),
);

final subscriptionOrdersProvider = FutureProvider.autoDispose<List<SubscriptionOrderEntity>>(
  (ref) => ref.watch(subscriptionsRepositoryProvider).listOrders(),
);

/// Tạo liên kết web checkout theo yêu cầu bấm nút (không tự gọi khi mở màn, khác các provider đọc ở trên).
final webSessionActionProvider =
    Provider.autoDispose<Future<WebSessionLinkEntity> Function({String? planId})>(
  (ref) => ({String? planId}) => ref.read(subscriptionsRepositoryProvider).createWebSession(planId: planId),
);
