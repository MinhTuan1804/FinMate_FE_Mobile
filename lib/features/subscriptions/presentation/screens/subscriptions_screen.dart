import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/subscriptions/presentation/controllers/subscriptions_controller.dart';

String _cycleLabel(String c) => switch (c) {
      'Monthly' => 'Theo tháng',
      'Yearly' => 'Theo năm',
      _ => c,
    };

String _statusLabel(String s) => switch (s) {
      'Pending' => 'Chờ thanh toán',
      'Paid' => 'Đã thanh toán',
      'Cancelled' => 'Đã hủy',
      'Expired' => 'Hết hạn',
      'Voided' => 'Đã hoàn tác',
      'NeedsReview' => 'Cần kiểm tra lại',
      _ => s,
    };

Color _statusColor(String s) => switch (s) {
      'Paid' => AppColors.safe,
      'Pending' => AppColors.warning,
      'NeedsReview' => AppColors.danger,
      _ => AppColors.textMutedDark,
    };

String _priceLabel(BigInt? cents) => cents == null ? 'Không bán' : '${cents ~/ BigInt.from(100)} đ';

/// Màn test `GET /api/v1/subscriptions/{plans,me,orders}` + `POST /web-session`.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gói đăng ký')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySubscriptionProvider);
          ref.invalidate(subscriptionPlansProvider);
          ref.invalidate(subscriptionOrdersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const _MySubscriptionSection(),
            const SizedBox(height: AppSpacing.lg),
            const _PlansSection(),
            const SizedBox(height: AppSpacing.lg),
            const _OrdersSection(),
            const SizedBox(height: AppSpacing.lg),
            const _WebSessionButton(),
          ],
        ),
      ),
    );
  }
}

class _MySubscriptionSection extends ConsumerWidget {
  const _MySubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mineAsync = ref.watch(mySubscriptionProvider);
    return mineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Lỗi tải gói hiện tại: ${errorMessage(e)}'),
      data: (mine) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gói hiện tại', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text('${mine.planName} (${mine.planCode})', key: const ValueKey('my-sub-plan-name')),
              Text('Miễn phí: ${mine.isFree}'),
              Text('Tính năng gói đang bật: ${mine.enabled}'),
              if (mine.expiresAt != null) Text('Hết hạn: ${mine.expiresAt}'),
              Text('Gói tiếp theo bắt đầu: ${mine.nextPurchaseStartsAt}'),
              if (mine.upcoming.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Đã xếp hàng chờ:', style: Theme.of(context).textTheme.labelLarge),
                for (final p in mine.upcoming) Text('${p.planName}: ${p.startsAt} → ${p.endsAt}'),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text('Lượt dùng chức năng tháng này:', style: Theme.of(context).textTheme.labelLarge),
              for (final f in mine.features)
                Text('${f.name}: ${f.enabled ? "${f.used}/${f.monthlyLimit ?? "không giới hạn"}" : "chưa mở"}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlansSection extends ConsumerWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Lỗi tải danh sách gói: ${errorMessage(e)}'),
      data: (plans) {
        if (plans.isEmpty) return const Text('Chưa có gói nào đang bán.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Các gói đang bán', style: Theme.of(context).textTheme.titleMedium),
            for (final p in plans)
              Card(
                key: ValueKey('plan-${p.code}'),
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: Theme.of(context).textTheme.titleSmall),
                      if (p.description != null) Text(p.description!),
                      Text('Theo tháng: ${_priceLabel(p.monthlyPriceCents)} • Theo năm: ${_priceLabel(p.yearlyPriceCents)}'),
                      for (final f in p.features)
                        Text('${f.enabled ? "✓" : "✗"} ${f.name}${f.monthlyLimit != null ? " (${f.monthlyLimit}/tháng)" : ""}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrdersSection extends ConsumerWidget {
  const _OrdersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(subscriptionOrdersProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Lỗi tải lịch sử đơn: ${errorMessage(e)}'),
      data: (orders) {
        if (orders.isEmpty) return const Text('Bạn chưa có đơn mua gói nào.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch sử đơn', style: Theme.of(context).textTheme.titleMedium),
            for (final o in orders)
              ListTile(
                key: ValueKey('order-${o.invoiceNumber}'),
                title: Text('${o.planName} • ${_cycleLabel(o.cycle)}'),
                subtitle: Text('${o.invoiceNumber} • ${o.createdAt}'),
                trailing: Text(_statusLabel(o.status), style: TextStyle(color: _statusColor(o.status))),
              ),
          ],
        );
      },
    );
  }
}

class _WebSessionButton extends ConsumerWidget {
  const _WebSessionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const ValueKey('create-web-session'),
      icon: const Icon(Icons.open_in_browser),
      label: const Text('Tạo liên kết mua/gia hạn gói'),
      onPressed: () async {
        final createWebSession = ref.read(webSessionActionProvider);
        try {
          final link = await createWebSession();
          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Liên kết web checkout'),
              content: SelectableText(link.url, key: const ValueKey('web-session-url')),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
              ],
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
        }
      },
    );
  }
}
