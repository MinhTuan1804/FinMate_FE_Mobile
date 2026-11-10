import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/support/presentation/controllers/support_controller.dart';

String _scopeLabel(String s) => switch (s) {
      'Accounts' => 'Danh sách ví',
      'Transactions' => 'Giao dịch',
      'Budgets' => 'Hạn mức',
      'Draft' => 'Tạo giao dịch nháp',
      _ => s,
    };

/// Màn test "ai đã xem dữ liệu của tôi" — GET /api/v1/support/access-log.
class SupportAccessLogScreen extends ConsumerWidget {
  const SupportAccessLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(supportAccessLogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký truy cập')),
      body: logAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(supportErrorMessage(e))),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Chưa có ai xem dữ liệu của bạn.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                key: ValueKey('support-access-log-$i'),
                leading: const Icon(Icons.visibility_outlined),
                title: Text(_scopeLabel(e.scope)),
                subtitle: Text('Ca #${e.ticketId.substring(0, 8)} • ${e.viewedAt}'),
              );
            },
          );
        },
      ),
    );
  }
}
