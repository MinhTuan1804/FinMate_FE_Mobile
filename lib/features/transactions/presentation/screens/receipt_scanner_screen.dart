import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';

/// Màn D4: Quét hóa đơn & Trích xuất thông minh (Receipt Scanner Screen)
class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  ConsumerState<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isProcessing = false;
  Map<String, dynamic>? _extractedData;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920);
      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _isProcessing = true;
        _extractedData = null;
      });

      // Mô phỏng AI / ML OCR trích xuất hóa đơn
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _extractedData = {
          'merchant': 'Siêu thị WinMart+',
          'date': DateTime.now(),
          'total': 185000,
          'category': 'Ăn uống / Nhu yếu phẩm',
          'items': [
            {'name': 'Sữa tươi TH True Milk 1L', 'price': 38000},
            {'name': 'Bánh mì sandwich ngũ cốc', 'price': 27000},
            {'name': 'Thịt nạc dăm heo 400g', 'price': 72000},
            {'name': 'Rau cải ngọt canh', 'price': 18000},
            {'name': 'Trứng gà Ba Huân hộp 10 quả', 'price': 30000},
          ],
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _createTransactionFromReceipt() {
    if (_extractedData == null) return;
    context.pop();
    CreateTransactionBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét hóa đơn'),
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
              // Scanner Camera / Upload Box
              if (_imageFile == null) ...[
                LiquidGlassCard(
                  variant: LiquidGlassVariant.standard,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.scanLine, size: 36, color: AppColors.secondary),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Chụp hoặc tải ảnh hóa đơn',
                        textAlign: TextAlign.center,
                        style: AppTypography.h2(context).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI FinMate sẽ tự động trích xuất tên cửa hàng, ngày giờ, danh sách món và tổng số tiền.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(context).copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(LucideIcons.image, size: 18),
                              label: const Text('Thư viện'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(LucideIcons.camera, size: 18),
                              label: const Text('Chụp ảnh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryAction(context),
                                foregroundColor: AppColors.onPrimaryAction(context),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Receipt Image Preview
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: AppSpacing.roundedLarge,
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.glassBorderLight),
                          borderRadius: AppSpacing.roundedLarge,
                        ),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: LiquidGlassIconButton(
                        icon: LucideIcons.rotateCcw,
                        size: 38,
                        tooltip: 'Chọn ảnh khác',
                        onPressed: () => setState(() {
                          _imageFile = null;
                          _extractedData = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Processing State
              if (_isProcessing) ...[
                const SizedBox(height: 24),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'AI đang đọc và phân tích hóa đơn...',
                        style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đang nhận diện món hàng và đối soát chi tiêu',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
              ],

              // Extracted Receipt Details
              if (_extractedData != null) ...[
                ZenvestHeroDeck(
                  peekBadgeText: 'OCR',
                  child: LiquidGlassCard(
                    variant: LiquidGlassVariant.iridescentHero,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.safe.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.checkCheck, color: AppColors.safe, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _extractedData!['merchant'] as String,
                                    style: AppTypography.h2(context).copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm - dd/MM/yyyy').format(_extractedData!['date'] as DateTime),
                                    style: AppTypography.caption(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Tổng tiền', style: AppTypography.caption(context)),
                            Text(
                              formatVnd(BigInt.from(_extractedData!['total'] as int)),
                              style: AppTypography.displayBalance(context).copyWith(
                                fontSize: 24,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Items list
                ZenvestSurfaceSheet(
                  title: 'Chi tiết các món hàng',
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      for (final item in (_extractedData!['items'] as List<Map<String, dynamic>>)) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.circleDot, size: 10, color: AppColors.secondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item['name'] as String,
                                  style: AppTypography.body(context).copyWith(fontSize: 13.5),
                                ),
                              ),
                              Text(
                                formatVnd(BigInt.from(item['price'] as int)),
                                style: AppTypography.tabular(
                                  AppTypography.caption(context).copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                LiquidGlassPillButton(
                  label: 'Tạo giao dịch từ hóa đơn này',
                  icon: LucideIcons.arrowRight,
                  isFullWidth: true,
                  onPressed: _createTransactionFromReceipt,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
