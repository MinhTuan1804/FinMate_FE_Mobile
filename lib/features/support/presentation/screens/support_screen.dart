import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/support/data/support_repository.dart';
import 'package:finmate/features/support/presentation/controllers/support_controller.dart';

const _categories = [
  'Security',
  'Account',
  'Transaction',
  'Receipt',
  'Notification',
  'Group',
  'Question',
];

String _categoryLabel(String c) => switch (c) {
      'Security' => 'An toàn tài khoản',
      'Account' => 'Tài khoản',
      'Transaction' => 'Giao dịch',
      'Receipt' => 'Hóa đơn',
      'Notification' => 'Thông báo',
      'Group' => 'Nhóm',
      'Question' => 'Câu hỏi khác',
      _ => c,
    };

String _statusLabel(String s) => switch (s) {
      'New' => 'Mới',
      'InProgress' => 'Đang xử lý',
      'WaitingCustomer' => 'Chờ bạn phản hồi',
      'Escalated' => 'Đã chuyển cấp cao hơn',
      'Resolved' => 'Đã giải quyết',
      'Closed' => 'Đã đóng',
      _ => s,
    };

Color _statusColor(String s) => switch (s) {
      'Closed' => AppColors.textMutedDark,
      'Resolved' => AppColors.safe,
      'Escalated' => AppColors.danger,
      'WaitingCustomer' => AppColors.warning,
      _ => AppColors.secondary,
    };

/// Màn test danh sách + tạo yêu cầu hỗ trợ (`/api/v1/support/tickets`).
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  Future<void> _createTicket(BuildContext context, WidgetRef ref) async {
    String category = _categories.first;
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tạo yêu cầu hỗ trợ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('support-category'),
                  initialValue: category,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(_categoryLabel(c))))
                      .toList(),
                  onChanged: (v) => setState(() => category = v ?? category),
                  decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('support-subject'),
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('support-body'),
                  controller: bodyCtrl,
                  decoration: const InputDecoration(labelText: 'Nội dung'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi')),
          ],
        ),
      ),
    );

    if (created != true || !context.mounted) return;
    try {
      final detail = await ref.read(supportRepositoryProvider).createTicket(
            category: category,
            subject: subjectCtrl.text,
            body: bodyCtrl.text,
          );
      ref.invalidate(supportTicketsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo yêu cầu hỗ trợ.')));
        context.push('/support-ticket', extra: detail.ticket.id);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(supportErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ'),
        actions: [
          IconButton(
            key: const ValueKey('support-access-log'),
            icon: const Icon(Icons.history),
            tooltip: 'Nhật ký truy cập',
            onPressed: () => context.push('/support-access-log'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('support-create'),
        onPressed: () => _createTicket(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(supportErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: () => ref.invalidate(supportTicketsProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(child: Text('Bạn chưa có yêu cầu hỗ trợ nào.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final t = tickets[i];
              return Card(
                child: ListTile(
                  key: ValueKey('support-ticket-${t.id}'),
                  title: Text(t.subject),
                  subtitle: Text('${_categoryLabel(t.category)} • ${_statusLabel(t.status)}'),
                  trailing: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: _statusColor(t.status), shape: BoxShape.circle),
                  ),
                  onTap: () => context.push('/support-ticket', extra: t.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
