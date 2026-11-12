import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

enum TicketStatus { open, inProgress, closed }

class SupportTicket {
  final String id;
  final String title;
  final String category;
  final TicketStatus status;
  final DateTime createdAt;
  final String lastMessage;

  const SupportTicket({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.lastMessage,
  });
}

/// Màn H16 & H17: Trung tâm hỗ trợ & Danh sách Ticket (Support Center)
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final List<SupportTicket> _tickets = [
    SupportTicket(
      id: 'TK-1082',
      title: 'Hỗ trợ đồng bộ giao dịch ngân hàng VPBank',
      category: 'Kỹ thuật',
      status: TicketStatus.inProgress,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      lastMessage: 'Nhân viên hỗ trợ: Đang kiểm tra lại định dạng thông báo VietQR...',
    ),
    SupportTicket(
      id: 'TK-1045',
      title: 'Tư vấn phương pháp phân bổ hũ chi tiêu 50/30/20',
      category: 'Tư vấn',
      status: TicketStatus.closed,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lastMessage: 'Đã giải quyết: Người dùng đã hoàn thành khảo sát và chọn hũ phù hợp.',
    ),
  ];

  void _createNewTicket() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String category = 'Kỹ thuật';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Gửi yêu cầu hỗ trợ mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Tiêu đề vấn đề'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Chủ đề'),
                  items: const [
                    DropdownMenuItem(value: 'Kỹ thuật', child: Text('Kỹ thuật & Lỗi ứng dụng')),
                    DropdownMenuItem(value: 'Tài khoản', child: Text('Tài khoản & Đăng nhập')),
                    DropdownMenuItem(value: 'Gói dịch vụ', child: Text('Gói cước & Thanh toán')),
                    DropdownMenuItem(value: 'Góp ý', child: Text('Góp ý tính năng mới')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  setState(() {
                    _tickets.insert(
                      0,
                      SupportTicket(
                        id: 'TK-${DateTime.now().millisecondsSinceEpoch % 10000}',
                        title: titleController.text.trim(),
                        category: category,
                        status: TicketStatus.open,
                        createdAt: DateTime.now(),
                        lastMessage: messageController.text.trim().isNotEmpty
                            ? messageController.text.trim()
                            : 'Yêu cầu vừa được khởi tạo.',
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã gửi yêu cầu hỗ trợ! Nhân viên sẽ phản hồi sớm.')),
                  );
                }
              },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(TicketStatus status) {
    return switch (status) {
      TicketStatus.open => AppColors.secondary,
      TicketStatus.inProgress => AppColors.warning,
      TicketStatus.closed => AppColors.safe,
    };
  }

  String _statusLabel(TicketStatus status) {
    return switch (status) {
      TicketStatus.open => 'Mới mở',
      TicketStatus.inProgress => 'Đang xử lý',
      TicketStatus.closed => 'Đã đóng',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm hỗ trợ'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTicket,
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.messageSquarePlus, size: 18),
        label: const Text('Tạo ticket mới'),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Contact Card
              ZenvestHeroDeck(
                peekBadgeText: 'HELP',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.headset, color: AppColors.secondary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đội ngũ hỗ trợ FinMate',
                                  style: AppTypography.h2(context).copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Thời gian phản hồi thông thường: dưới 15 phút',
                                  style: AppTypography.caption(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Bạn đang gặp sự cố về tài khoản, giao dịch hoặc cần tư vấn phương pháp quản lý tài chính? Đội ngũ hỗ trợ luôn sẵn sàng đồng hành.',
                        style: AppTypography.caption(context).copyWith(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('DANH SÁCH YÊU CẦU HỖ TRỢ (TICKETS)', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              for (final ticket in _tickets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LiquidGlassCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () => context.push('/profile/support/ticket', extra: ticket),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              ticket.id,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(ticket.status).withValues(alpha: 0.15),
                                borderRadius: AppSpacing.roundedPill,
                              ),
                              child: Text(
                                _statusLabel(ticket.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(ticket.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.title,
                          style: AppTypography.body(context).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.lastMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('HH:mm - dd/MM/yyyy').format(ticket.createdAt),
                              style: AppTypography.caption(context).copyWith(fontSize: 11.5),
                            ),
                            const Row(
                              children: [
                                Text('Xem chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                SizedBox(width: 4),
                                Icon(LucideIcons.chevronRight, size: 14),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
