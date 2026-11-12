import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/profile/presentation/screens/support_screen.dart';

class TicketMessage {
  final String sender; // 'user' hoặc 'support'
  final String text;
  final DateTime time;

  const TicketMessage({required this.sender, required this.text, required this.time});
}

/// Màn H18 & H19: Chi tiết Ticket kiểu Chat & Duyệt quyền truy cập hỗ trợ (Support Ticket Detail & Access Grant)
class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  final SupportTicket ticket;

  const SupportTicketDetailScreen({super.key, required this.ticket});

  @override
  ConsumerState<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends ConsumerState<SupportTicketDetailScreen> {
  final _inputController = TextEditingController();
  bool _staffAccessGranted = false;

  late final List<TicketMessage> _messages = [
    TicketMessage(
      sender: 'user',
      text: 'Chào FinMate, tôi gặp lỗi khi quét mã QR của VPBank thì không nhận diện được tên người nhận.',
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    TicketMessage(
      sender: 'support',
      text: 'Chào bạn, đội ngũ hỗ trợ đã tiếp nhận. Để kiểm tra nhật ký đọc mã VietQR, bạn có thể cấp quyền xem dữ liệu chẩn đoán tạm thời (24h) không?',
      time: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(TicketMessage(sender: 'user', text: text, time: DateTime.now()));
      _inputController.clear();
    });
  }

  void _toggleStaffAccess() {
    final willGrant = !_staffAccessGranted;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willGrant ? 'Cấp quyền truy cập cho nhân viên hỗ trợ?' : 'Thu hồi quyền truy cập?'),
        content: Text(
          willGrant
              ? 'Nhân viên hỗ trợ sẽ được cấp quyền đọc nhật ký lỗi và chẩn đoán ứng dụng trong 24 giờ. Cam kết bảo mật Zero-Credential (không thấy mật khẩu/mã PIN).'
              : 'Quyền truy cập của nhân viên hỗ trợ sẽ bị đóng ngay lập tức.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _staffAccessGranted = willGrant);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(willGrant ? 'Đã cấp quyền hỗ trợ trong 24 giờ.' : 'Đã thu hồi quyền hỗ trợ.'),
                ),
              );
            },
            child: Text(willGrant ? 'Đồng ý cấp quyền' : 'Thu hồi quyền'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket.id),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _staffAccessGranted ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
              color: _staffAccessGranted ? AppColors.safe : AppColors.warning,
            ),
            tooltip: 'Quyền truy cập hỗ trợ',
            onPressed: _toggleStaffAccess,
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: Column(
          children: [
            // Staff Access Banner (H19)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: (_staffAccessGranted ? AppColors.safe : AppColors.warning).withValues(alpha: 0.12),
              child: Row(
                children: [
                  Icon(
                    _staffAccessGranted ? LucideIcons.shieldCheck : LucideIcons.shield,
                    size: 18,
                    color: _staffAccessGranted ? AppColors.safe : AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _staffAccessGranted
                          ? 'Đã cấp quyền chẩn đoán hỗ trợ (hết hạn sau 23 giờ)'
                          : 'Nhân viên chưa có quyền xem log chẩn đoán',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _staffAccessGranted ? AppColors.safe : AppColors.warning,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleStaffAccess,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: const Size(40, 26),
                    ),
                    child: Text(_staffAccessGranted ? 'Thu hồi' : 'Cấp quyền'),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg.sender == 'user';
                  final bubbleColor = isUser
                      ? AppColors.primaryAction(context)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E2B45)
                          : Colors.white);
                  final textColor = isUser
                      ? AppColors.onPrimaryAction(context)
                      : AppColors.textPrimary(context);

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUser ? 'Bạn' : 'Hỗ trợ FinMate',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            msg.text,
                            style: TextStyle(fontSize: 13.5, color: textColor, height: 1.35),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              DateFormat('HH:mm').format(msg.time),
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn phản hồi...',
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E2B45)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  LiquidGlassIconButton(
                    icon: LucideIcons.send,
                    style: LiquidGlassButtonStyle.primary,
                    size: 44,
                    tooltip: 'Gửi',
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
