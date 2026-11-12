import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn H5 & H6: Sao lưu, Xuất & Nhập dữ liệu tài chính (Backup & Data Import/Export Screen)
class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({super.key});

  @override
  ConsumerState<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  bool _isBackingUp = false;
  DateTime? _lastBackupTime = DateTime.now().subtract(const Duration(days: 1, hours: 3));

  Future<void> _handleBackupNow() async {
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _isBackingUp = false;
      _lastBackupTime = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sao lưu cơ sở dữ liệu mã hóa lên đám mây thành công!'),
        backgroundColor: AppColors.safe,
      ),
    );
  }

  void _exportFormat(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang tạo và tải tệp xuất định dạng $format...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startImportFlow() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quy trình nhập dữ liệu (4 bước)',
              style: AppTypography.h2(context).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 14),
            _stepRow('Bước 1', 'Chọn file sao lưu (.json hoặc .csv từ ngân hàng)'),
            _stepRow('Bước 2', 'Đối chiếu cột ngày, danh mục và số tiền'),
            _stepRow('Bước 3', 'Xem trước 10 giao dịch mẫu và kiểm tra trùng lặp'),
            _stepRow('Bước 4', 'Xác nhận nhập vào sổ thu chi FinMate'),
            const SizedBox(height: 20),
            LiquidGlassPillButton(
              label: 'Chọn tệp từ thiết bị',
              icon: LucideIcons.fileUp,
              isFullWidth: true,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng nhập file đang kết nối API backend')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: AppSpacing.roundedPill,
            ),
            child: Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Dữ liệu'),
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
              // Hero Cloud Card
              ZenvestHeroDeck(
                peekBadgeText: 'CLOUD',
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
                              color: AppColors.safe.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.cloudCheck, color: AppColors.safe, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đồng bộ đám mây an toàn',
                                  style: AppTypography.h2(context).copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _lastBackupTime != null
                                      ? 'Lần sao lưu gần nhất: ${DateFormat('HH:mm - dd/MM/yyyy').format(_lastBackupTime!)}'
                                      : 'Chưa có bản sao lưu nào',
                                  style: AppTypography.caption(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LiquidGlassPillButton(
                        label: _isBackingUp ? 'Đang tạo bản sao lưu...' : 'Sao lưu ngay lập tức',
                        icon: LucideIcons.refreshCw,
                        isFullWidth: true,
                        onPressed: _isBackingUp ? () {} : _handleBackupNow,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('XUẤT DỮ LIỆU TÀI CHÍNH (EXPORT)', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    _exportTile(
                      title: 'Xuất file bảng tính Excel (.xlsx)',
                      subtitle: 'Đầy đủ thu chi, danh mục, ví và công thức tổng',
                      icon: LucideIcons.sheet,
                      onTap: () => _exportFormat('Excel (.xlsx)'),
                    ),
                    const Divider(height: 16),
                    _exportTile(
                      title: 'Xuất file CSV chuẩn (.csv)',
                      subtitle: 'Tương thích nhập vào Google Sheets hoặc Notion',
                      icon: LucideIcons.fileSpreadsheet,
                      onTap: () => _exportFormat('CSV'),
                    ),
                    const Divider(height: 16),
                    _exportTile(
                      title: 'Bản sao lưu bảo mật (.finmate)',
                      subtitle: 'File mã hóa đầy đủ để khôi phục trên máy mới',
                      icon: LucideIcons.shieldCheck,
                      onTap: () => _exportFormat('FinMate Backup (.finmate)'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text('NHẬP DỮ LIỆU (IMPORT)', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              LiquidGlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.fileDown, color: AppColors.secondary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhập từ file sao lưu cũ',
                            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hỗ trợ CSV sao kê ngân hàng và file dữ liệu FinMate',
                            style: AppTypography.caption(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: _startImportFlow,
                      child: const Text('Nhập file'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primaryAction(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption(context).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}
