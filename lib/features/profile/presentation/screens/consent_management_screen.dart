import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class ConsentItemData {
  final String key;
  final String title;
  final String description;
  final bool isRequired;
  bool isGranted;
  final DateTime? grantedDate;

  ConsentItemData({
    required this.key,
    required this.title,
    required this.description,
    this.isRequired = false,
    required this.isGranted,
    this.grantedDate,
  });
}

/// Màn H11: Quản lý Quyền đồng ý & Dữ liệu (Consent Management Screen)
class ConsentManagementScreen extends ConsumerStatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  ConsumerState<ConsentManagementScreen> createState() => _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends ConsumerState<ConsentManagementScreen> {
  late List<ConsentItemData> _consents = [
    ConsentItemData(
      key: 'terms',
      title: 'Điều khoản sử dụng & Quy định dịch vụ',
      description: 'Điều kiện bắt buộc để duy trì và kích hoạt tài khoản FinMate.',
      isRequired: true,
      isGranted: true,
      grantedDate: DateTime(2026, 9, 1),
    ),
    ConsentItemData(
      key: 'ai',
      title: 'Tính năng Trợ lý AI FinMate',
      description: 'Cho phép AI phân tích ngôn ngữ tự nhiên để trò chuyện và trích xuất hóa đơn.',
      isRequired: false,
      isGranted: true,
      grantedDate: DateTime(2026, 9, 1),
    ),
    ConsentItemData(
      key: 'training',
      title: 'Đóng góp huấn luyện mô hình (AI Training)',
      description: 'Dữ liệu được ẩn danh hóa tuyệt đối để cải thiện độ chính xác của AI.',
      isRequired: false,
      isGranted: false,
      grantedDate: null,
    ),
    ConsentItemData(
      key: 'survey',
      title: 'Khảo sát hành vi & Phương pháp tài chính',
      description: 'Cho phép app lưu trữ câu trả lời khảo sát để đề xuất phương pháp hũ chi tiêu.',
      isRequired: false,
      isGranted: true,
      grantedDate: DateTime(2026, 9, 5),
    ),
    ConsentItemData(
      key: 'community',
      title: 'Chia sẻ trong Diễn đàn Cộng đồng',
      description: 'Cho phép tài khoản của bạn tham gia thảo luận và đăng bài tại diễn đàn.',
      isRequired: false,
      isGranted: true,
      grantedDate: DateTime(2026, 9, 10),
    ),
  ];

  Future<void> _toggleConsent(ConsentItemData item, bool value) async {
    if (item.isRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đây là điều khoản bắt buộc của ứng dụng. Bạn chỉ có thể thu hồi bằng cách Xóa tài khoản.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Thu hồi quyền "${item.title}"?'),
          content: Text(
            'Nếu thu hồi, tính năng liên quan sẽ bị vô hiệu hóa và dữ liệu liên kết sẽ bị xóa.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Xác nhận thu hồi'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      item.isGranted = value;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Đã cấp quyền thành công.' : 'Đã thu hồi quyền thành công.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quyền đồng ý & Dữ liệu'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Info
              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.safe.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.shieldCheck, color: AppColors.safe, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minh bạch & Quyền riêng tư',
                            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bạn có toàn quyền kiểm soát cách FinMate sử dụng dữ liệu của mình bất cứ lúc nào.',
                            style: AppTypography.caption(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text('DANH SÁCH 5 QUYỀN ĐỒNG Ý', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              for (final item in _consents) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LiquidGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: AppTypography.body(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            Switch(
                              value: item.isGranted,
                              onChanged: (val) => _toggleConsent(item, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.isGranted && item.grantedDate != null
                              ? 'Đã đồng ý ngày: ${DateFormat('dd/MM/yyyy').format(item.grantedDate!)}'
                              : (item.isGranted ? 'Đã bật' : 'Chưa cấp quyền / Đã thu hồi'),
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 11,
                            color: item.isGranted ? AppColors.safe : AppColors.textMuted(context),
                            fontWeight: FontWeight.w600,
                          ),
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
