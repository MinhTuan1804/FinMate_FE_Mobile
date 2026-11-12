import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class AiMemoryItem {
  final String id;
  final String key;
  final String value;
  final String category;
  final DateTime updatedAt;

  const AiMemoryItem({
    required this.id,
    required this.key,
    required this.value,
    required this.category,
    required this.updatedAt,
  });
}

/// Màn E3: Bộ nhớ AI (AI Memory Screen)
class AiMemoryScreen extends ConsumerStatefulWidget {
  const AiMemoryScreen({super.key});

  @override
  ConsumerState<AiMemoryScreen> createState() => _AiMemoryScreenState();
}

class _AiMemoryScreenState extends ConsumerState<AiMemoryScreen> {
  List<AiMemoryItem> _memories = [
    AiMemoryItem(
      id: 'm1',
      key: 'Thói quen chi tiêu cà phê',
      value: 'Thường uống Highlands Coffee hoặc The Coffee House vào 8:30 sáng các ngày trong tuần.',
      category: 'Thói quen',
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AiMemoryItem(
      id: 'm2',
      key: 'Nguyên tắc ngân sách',
      value: 'Ưu tiên không vượt quá 300.000 ₫/ngày cho ăn uống để dành tiền đi du lịch cuối năm.',
      category: 'Mục tiêu',
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    AiMemoryItem(
      id: 'm3',
      key: 'Tài khoản nhận lương chính',
      value: 'Lương chuyển về Techcombank vào ngày 5 hàng tháng, thường trích ngay 20% sang quỹ tiết kiệm.',
      category: 'Tài khoản',
      updatedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    AiMemoryItem(
      id: 'm4',
      key: 'Sở thích & ưu đãi',
      value: 'Ưa thích thanh toán qua mã QR VietQR hoặc quét hóa đơn để kiểm tra đối soát tự động.',
      category: 'Thói quen',
      updatedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  void _deleteSingle(String id) {
    setState(() {
      _memories.removeWhere((item) => item.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa ghi nhớ này khỏi bộ nhớ AI'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ bộ nhớ AI?'),
        content: const Text(
          'Trợ lý AI FinMate sẽ quên tất cả thói quen, sở thích và ghi nhớ cá nhân của bạn. Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _memories.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa sạch bộ nhớ AI'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bộ nhớ Trợ lý AI'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_memories.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
              tooltip: 'Xóa toàn bộ',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.sparkles, color: AppColors.secondary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bộ nhớ học máy cá nhân',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI tự động ghi nhớ các thói quen tài chính để tư vấn chính xác hơn. Bạn có toàn quyền xóa bất kỳ thông tin nào.',
                            style: AppTypography.caption(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              if (_memories.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(LucideIcons.brain, size: 52, color: AppColors.textMuted(context)),
                        const SizedBox(height: 14),
                        Text(
                          'Bộ nhớ AI đang trống',
                          style: AppTypography.h2(context).copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Khi bạn trò chuyện và ghi chép, AI sẽ dần học thói quen của bạn.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                for (final item in _memories) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LiquidGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: AppSpacing.roundedPill,
                                ),
                                child: Text(
                                  item.category,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slateAction,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _deleteSingle(item.id),
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(LucideIcons.x, size: 16, color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.key,
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value,
                            style: AppTypography.caption(context).copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
