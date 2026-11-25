import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/support/data/support_image_source.dart';
import 'package:finmate/features/support/domain/support.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/support/presentation/controllers/support_controller.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

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

/// Nền kính dùng chung cho thẻ và bong bóng, cùng kiểu các màn khác
BoxDecoration _glass(
  BuildContext context, {
  double radius = 24,
  BorderRadius? borderRadius,
}) => BoxDecoration(
  color: AppColors.isDark(context)
      ? AppColors.glassFillDark
      : AppColors.glassFillLight,
  borderRadius: borderRadius ?? BorderRadius.circular(radius),
  border: Border.all(color: AppColors.glassBorder(context)),
);

/// Màn test chi tiết 1 ca hỗ trợ: tin nhắn + trả lời + gửi ảnh, đóng ca, đánh giá, và danh sách yêu
/// cầu xem dữ liệu (đồng ý/từ chối/thu hồi).
class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
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
      await ref
          .read(ticketDetailControllerProvider(widget.ticketId).notifier)
          .reply(body);
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
    final body = _replyCtrl.text.trim().isEmpty
        ? '(đã gửi ảnh)'
        : _replyCtrl.text.trim();
    setState(() => _busy = true);
    try {
      final message = await ref
          .read(ticketDetailControllerProvider(widget.ticketId).notifier)
          .replyAndReturn(body);
      await ref
          .read(ticketDetailControllerProvider(widget.ticketId).notifier)
          .addAttachment(
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
      await ref
          .read(ticketDetailControllerProvider(widget.ticketId).notifier)
          .close();
      _showMessage('Đã đóng yêu cầu.');
    } catch (e) {
      _showMessage(supportErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(int stars) async {
    try {
      await ref
          .read(ticketDetailControllerProvider(widget.ticketId).notifier)
          .rate(stars);
      _showMessage('Đã đánh giá $stars/5.');
    } catch (e) {
      _showMessage(supportErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketDetailControllerProvider(widget.ticketId));

    return Scaffold(
      body: AmbientGlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    LiquidGlassIconButton(
                      icon: LucideIcons.arrowLeft,
                      tooltip: 'Quay lại',
                      iconSize: 18,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        'Chi tiết yêu cầu hỗ trợ',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge(context).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.minTouchTarget),
                  ],
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AsyncValue<SupportTicketDetailEntity?> state) {
    return state.when(
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
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: _glass(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: AppTypography.bodyLarge(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Trạng thái: ${_statusLabel(ticket.status)}',
                          style: AppTypography.caption(context),
                        ),
                        if (ticket.rating != null)
                          Text(
                            'Đánh giá: ${ticket.rating}/5',
                            style: AppTypography.caption(context),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        AsyncActionBuilder(
                          onPressed: ticket.isClosed || _busy ? null : _close,
                          builder: (_, onTap, running) => OutlinedButton(
                            key: const ValueKey('support-close'),
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: AppColors.glassBorder(context),
                              ),
                            ),
                            child: running ? const ButtonLoadingIndicator() : const Text('Đóng yêu cầu'),
                          ),
                        ),
                        if (ticket.canRate && ticket.rating == null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Đánh giá hỗ trợ',
                            style: AppTypography.caption(context),
                          ),
                          Wrap(
                            children: List.generate(
                              5,
                              (i) => IconButton(
                                key: ValueKey('support-rate-${i + 1}'),
                                tooltip: '${i + 1} sao',
                                icon: const Icon(LucideIcons.star, size: 22),
                                onPressed: () => _rate(i + 1),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final m in detail.messages)
                    Align(
                      alignment: m.kind == 'Customer'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: m.kind == 'Customer'
                            ? BoxDecoration(
                                color: AppColors.primaryAction(context),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(22),
                                  topRight: Radius.circular(22),
                                  bottomLeft: Radius.circular(22),
                                  bottomRight: Radius.circular(6),
                                ),
                              )
                            : _glass(
                                context,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(22),
                                  topRight: Radius.circular(22),
                                  bottomRight: Radius.circular(22),
                                  bottomLeft: Radius.circular(6),
                                ),
                              ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.body,
                              style: AppTypography.body(context).copyWith(
                                color: m.kind == 'Customer'
                                    ? AppColors.onPrimaryAction(context)
                                    : null,
                              ),
                            ),
                            if (m.attachments.isNotEmpty)
                              Text(
                                '${m.attachments.length} ảnh đính kèm',
                                style: AppTypography.caption(context).copyWith(
                                  color: m.kind == 'Customer'
                                      ? AppColors.onPrimaryAction(
                                          context,
                                        ).withValues(alpha: 0.75)
                                      : null,
                                ),
                              ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _glass(context, radius: 999),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('support-reply-image'),
                        tooltip: 'Đính kèm ảnh',
                        icon: const Icon(LucideIcons.image, size: 20),
                        onPressed: _busy ? null : _replyWithImage,
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('support-reply-input'),
                          controller: _replyCtrl,
                          style: AppTypography.body(context),
                          decoration: const InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('support-reply-send'),
                        tooltip: 'Gửi',
                        style: IconButton.styleFrom(
                          fixedSize: const Size(44, 44),
                          backgroundColor: AppColors.primaryAction(context),
                          foregroundColor: AppColors.onPrimaryAction(context),
                          disabledBackgroundColor: AppColors.primaryAction(
                            context,
                          ).withValues(alpha: 0.35),
                        ),
                        icon: const Icon(LucideIcons.arrowUp, size: 18),
                        onPressed: _busy ? null : _reply,
                      ),
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

class _AccessRequestsSection extends ConsumerWidget {
  const _AccessRequestsSection({required this.ticketId});

  final String ticketId;

  /// Yêu cầu có quyền tạo giao dịch nháp thì BE bắt chọn ví nhận giao dịch (422 nếu thiếu): hỏi ví trước, rồi mới đồng ý.
  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    SupportAccessRequestEntity r,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String? accountId;
    if (r.requiresDraftAccount) {
      final accounts =
          ref.read(accountsControllerProvider).valueOrNull ?? const [];
      if (accounts.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn cần có ít nhất một ví để nhận giao dịch nháp do nhân viên tạo.',
            ),
          ),
        );
        return;
      }
      accountId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Chọn ví nhận giao dịch nháp'),
          children: [
            for (final a in accounts)
              SimpleDialogOption(
                key: ValueKey('support-access-account-${a.id}'),
                onPressed: () => Navigator.pop(ctx, a.id),
                child: Text(a.name),
              ),
          ],
        ),
      );
      if (accountId == null) return;
    }
    try {
      await ref
          .read(accessRequestsControllerProvider(ticketId).notifier)
          .approve(r.id, financialAccountId: accountId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(supportErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accessRequestsControllerProvider(ticketId));
    final controller = ref.read(
      accessRequestsControllerProvider(ticketId).notifier,
    );

    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(supportErrorMessage(e)),
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: _glass(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yêu cầu xem dữ liệu của bạn',
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final r in requests)
                  Padding(
                    key: ValueKey('support-access-request-${r.id}'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.scopes.map(_scopeLabel).join(', '),
                          style: AppTypography.bodyMedium(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(r.reason, style: AppTypography.body(context)),
                        Text(
                          'Trạng thái: ${_accessStatusLabel(r.status)}',
                          style: AppTypography.caption(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (r.isPending)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              AsyncActionBuilder(
                                onPressed: () => _approve(context, ref, r),
                                builder: (_, onTap, running) => ElevatedButton(
                                  key: ValueKey('support-access-approve-${r.id}'),
                                  onPressed: onTap,
                                  child: running ? const ButtonLoadingIndicator() : const Text('Đồng ý'),
                                ),
                              ),
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
