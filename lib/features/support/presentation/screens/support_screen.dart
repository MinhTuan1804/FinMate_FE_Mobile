import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/support/domain/support.dart';
import 'package:finmate/features/support/presentation/controllers/support_controller.dart';

const supportCategories = [
  'Security',
  'Account',
  'Transaction',
  'Receipt',
  'Notification',
  'Group',
  'Question',
];

String supportCategoryLabel(String c) => switch (c) {
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

/// Bộ lọc nhanh theo trạng thái: Tất cả, Đang xử lý (mới/đang xử lý/chuyển cấp), Chờ bạn phản hồi, Đã xong (giải quyết/đóng).
enum _Filter { all, active, waiting, done }

bool _inFilter(_Filter f, String status) => switch (f) {
      _Filter.all => true,
      _Filter.active => status == 'New' || status == 'InProgress' || status == 'Escalated',
      _Filter.waiting => status == 'WaitingCustomer',
      _Filter.done => status == 'Resolved' || status == 'Closed',
    };

String _filterLabel(_Filter f) => switch (f) {
      _Filter.all => 'Tất cả',
      _Filter.active => 'Đang xử lý',
      _Filter.waiting => 'Chờ phản hồi',
      _Filter.done => 'Đã xong',
    };

/// Màn H16: Hỗ trợ & Yêu cầu (theo Figma), danh sách + tạo yêu cầu hỗ trợ thật (`/api/v1/support/tickets`).
/// Hội viên Pro, tên chuyên viên và thời gian phản hồi trung bình trong Figma chưa có ở BE nên không hiển thị.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  void _createTicket(BuildContext context, WidgetRef ref) => context.push('/support/new');

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ & Yêu cầu'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [
          IconButton(
            key: const ValueKey('support-access-log'),
            icon: const Icon(LucideIcons.history),
            tooltip: 'Nhật ký truy cập',
            onPressed: () => context.push('/support-access-log'),
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.refresh(supportTicketsProvider.future),
                child: ticketsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      Text(supportErrorMessage(e), textAlign: TextAlign.center, style: AppTypography.body(context)),
                      const SizedBox(height: AppSpacing.lg),
                      Center(child: ElevatedButton(onPressed: () => ref.invalidate(supportTicketsProvider), child: const Text('Thử lại'))),
                    ],
                  ),
                  data: (tickets) => _list(context, tickets),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: LiquidGlassPillButton(
                  key: const ValueKey('support-create'),
                  label: 'Tạo yêu cầu hỗ trợ mới',
                  icon: LucideIcons.plus,
                  isFullWidth: true,
                  onPressed: () => _createTicket(context, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<SupportTicketEntity> tickets) {
    final q = _query.trim().toLowerCase();
    final shown = tickets.where((t) => _inFilter(_filter, t.status) && (q.isEmpty || t.subject.toLowerCase().contains(q) || t.id.toLowerCase().contains(q))).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        LiquidGlassCard(
          variant: LiquidGlassVariant.iridescentHero,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: Icon(LucideIcons.headset, size: 22, color: AppColors.slateOn(context)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trung tâm trợ giúp', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Gửi yêu cầu và theo dõi phản hồi từ đội ngũ hỗ trợ FinMate.', style: AppTypography.caption(context).copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('support-search'),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Tìm theo mã ticket hoặc nội dung...',
            prefixIcon: const Icon(LucideIcons.search, size: 16),
            filled: true,
            fillColor: AppColors.inset(context, 0.55),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: AppSpacing.roundedPill, borderSide: BorderSide(color: AppColors.insetBorder(context))),
            enabledBorder: OutlineInputBorder(borderRadius: AppSpacing.roundedPill, borderSide: BorderSide(color: AppColors.insetBorder(context))),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('support-filter-${f.name}'),
                    label: Text('${_filterLabel(f)} ${tickets.where((t) => _inFilter(f, t.status)).length}'),
                    selected: _filter == f,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _filter == f ? AppColors.activeFg(context) : AppColors.textSecondary(context)),
                    selectedColor: AppColors.activeFill(context),
                    backgroundColor: AppColors.chipFill(context),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (tickets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Bạn chưa có yêu cầu hỗ trợ nào.', textAlign: TextAlign.center, style: AppTypography.body(context)),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Không có yêu cầu phù hợp.', textAlign: TextAlign.center, style: AppTypography.body(context)),
          ),
        for (final t in shown) _ticketCard(context, t),
      ],
    );
  }

  Widget _ticketCard(BuildContext context, SupportTicketEntity t) {
    final color = _statusColor(t.status);
    final shortId = t.id.length > 8 ? t.id.substring(0, 8) : t.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: AppSpacing.roundedLarge,
        child: Stack(
          children: [
            LiquidGlassCard(
              variant: LiquidGlassVariant.subtle, // dòng trong list: không blur từng item
              key: ValueKey('support-ticket-${t.id}'),
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
              onTap: () => context.push('/support-ticket', extra: t.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#$shortId', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
                          child: Text(supportCategoryLabel(t.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.slateOn(context))),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: AppSpacing.roundedPill),
                        child: Text(_statusLabel(t.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(t.subject, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      if (t.rating != null) ...[
                        const Icon(LucideIcons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text('${t.rating}/5', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
                      ],
                      const Spacer(),
                      Icon(LucideIcons.clock, size: 13, color: AppColors.textMuted(context)),
                      const SizedBox(width: 4),
                      Text('Cập nhật ${DateFormat('dd/MM HH:mm').format(t.updatedAt.toLocal())}', style: AppTypography.caption(context).copyWith(fontSize: 11.5)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 5, color: color)),
          ],
        ),
      ),
    );
  }
}
