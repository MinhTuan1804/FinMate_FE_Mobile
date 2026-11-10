import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/support/data/support_image_source.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/support/presentation/controllers/support_controller.dart';

String _statusLabel(String s) => switch (s) {
      'New' => 'Mới',
      'InProgress' => 'Đang xử lý',
      'WaitingCustomer' => 'Chờ bạn phản hồi',
      'Escalated' => 'Đã chuyển cấp cao hơn',
      'Resolved' => 'Đã giải quyết',
      'Closed' => 'Đã đóng',
      _ => s,
    };

String _scopeLabel(String s) => switch (s) {
      'Accounts' => 'Danh sách ví',
      'Transactions' => 'Giao dịch',
      'Budgets' => 'Hạn mức',
      'Draft' => 'Tạo giao dịch nháp',
      _ => s,
    };

String _accessStatusLabel(String s) => switch (s) {
      'Pending' => 'Đang chờ bạn',
      'Approved' => 'Đã đồng ý',
      'Denied' => 'Đã từ chối',
      'Revoked' => 'Đã thu hồi',
      _ => s,
    };

/// Màn test chi tiết 1 ca hỗ trợ: tin nhắn + trả lời + gửi ảnh, đóng ca, đánh giá, và danh sách yêu
/// cầu xem dữ liệu (đồng ý/từ chối/thu hồi).
class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends ConsumerState<SupportTicketDetailScreen> {
  final _replyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _reply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(ticketDetailControllerProvider(widget.ticketId).notifier).reply(body);
      _replyCtrl.clear();
      _showMessage('Đã gửi tin nhắn.');
    } catch (e) {
      _showMessage(supportErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Gửi tin nhắn kèm ảnh: BE yêu cầu ảnh phải gắn vào MỘT tin nhắn cụ thể (route
  /// `/messages/{messageId}/attachments`), nên phải trả lời trước để có `messageId` rồi mới gửi ảnh lên đúng tin đó.
  Future<void> _replyWithImage() async {
    final picked = await ref.read(supportImageSourceProvider).pickFromGallery();
    if (picked == null) return;
    final body = _replyCtrl.text.trim().isEmpty ? '(đã gửi ảnh)' : _replyCtrl.text.trim();
    setState(() => _busy = true);
    try {
      final message = await ref.read(ticketDetailControllerProvider(widget.ticketId).notifier).replyAndReturn(body);
      await ref.read(ticketDetailControllerProvider(widget.ticketId).notifier).addAttachment(
            messageId: message.id,
            filePath: picked.path,
            fileName: picked.name,
          );
      _replyCtrl.clear();
      _showMessage('Đã gửi tin nhắn kèm ảnh.');
    } catch (e) {
      _showMessage(supportErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await ref.read(ticketDetailControllerProvider(widget.ticketId).notifier).close();
      _showMessage('Đã đóng yêu cầu.');
    } catch (e) {
      _showMessage(supportErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(int stars) async {
    try {
      await ref.read(ticketDetailControllerProvider(widget.ticketId).notifier).rate(stars);
      _showMessage('Đã đánh giá $stars/5.');
    } catch (e) {
      _showMessage(supportErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketDetailControllerProvider(widget.ticketId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết yêu cầu hỗ trợ')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(supportErrorMessage(e))),
        data: (detail) {
          if (detail == null) return const SizedBox.shrink();
          final ticket = detail.ticket;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: AppSpacing.xs),
                            Text('Trạng thái: ${_statusLabel(ticket.status)}'),
                            if (ticket.rating != null) Text('Đánh giá: ${ticket.rating}/5'),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                OutlinedButton(
                                  key: const ValueKey('support-close'),
                                  onPressed: ticket.isClosed || _busy ? null : _close,
                                  child: const Text('Đóng yêu cầu'),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                if (ticket.canRate && ticket.rating == null)
                                  Wrap(
                                    spacing: 2,
                                    children: List.generate(
                                      5,
                                      (i) => IconButton(
                                        key: ValueKey('support-rate-${i + 1}'),
                                        icon: const Icon(Icons.star_border, size: 20),
                                        onPressed: () => _rate(i + 1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final m in detail.messages)
                      Align(
                        alignment: m.kind == 'Customer' ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: m.kind == 'Customer' ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceLightSubtle,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body),
                              if (m.attachments.isNotEmpty)
                                Text('${m.attachments.length} ảnh đính kèm', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _AccessRequestsSection(ticketId: widget.ticketId),
                  ],
                ),
              ),
              if (!ticket.isClosed)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('support-reply-input'),
                            controller: _replyCtrl,
                            decoration: const InputDecoration(hintText: 'Nhập tin nhắn...', border: OutlineInputBorder()),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('support-reply-image'),
                          icon: const Icon(Icons.image),
                          onPressed: _busy ? null : _replyWithImage,
                        ),
                        IconButton(
                          key: const ValueKey('support-reply-send'),
                          icon: const Icon(Icons.send),
                          onPressed: _busy ? null : _reply,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AccessRequestsSection extends ConsumerWidget {
  const _AccessRequestsSection({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accessRequestsControllerProvider(ticketId));
    final controller = ref.read(accessRequestsControllerProvider(ticketId).notifier);

    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(supportErrorMessage(e)),
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yêu cầu xem dữ liệu của bạn', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                for (final r in requests)
                  Padding(
                    key: ValueKey('support-access-request-${r.id}'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.scopes.map(_scopeLabel).join(', '), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(r.reason),
                        Text('Trạng thái: ${_accessStatusLabel(r.status)}'),
                        if (r.isPending)
                          Row(
                            children: [
                              ElevatedButton(
                                key: ValueKey('support-access-approve-${r.id}'),
                                onPressed: () => controller.approve(r.id),
                                child: const Text('Đồng ý'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton(
                                key: ValueKey('support-access-deny-${r.id}'),
                                onPressed: () => controller.deny(r.id),
                                child: const Text('Từ chối'),
                              ),
                            ],
                          )
                        else if (r.isApproved)
                          OutlinedButton(
                            key: ValueKey('support-access-revoke-${r.id}'),
                            onPressed: () => controller.revoke(r.id),
                            child: const Text('Thu hồi quyền'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
