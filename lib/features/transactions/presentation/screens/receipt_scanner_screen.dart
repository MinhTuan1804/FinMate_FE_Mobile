import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';

/// Màn D4: Quét hóa đơn. Ảnh gửi lên `POST /transactions/scan-receipt` (cùng luồng với chat AI), kết quả chỉ là bản nháp:
/// người dùng rà soát ở màn `/assistant/review` rồi mới lưu giao dịch.
class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  ConsumerState<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  String? _imagePath;
  bool _isProcessing = false;
  ReceiptScan? _scan;
  String? _error;

  Future<void> _pick(Future<String?> Function(ReceiptImageSource) choose) async {
    final String? path;
    try {
      path = await choose(ref.read(receiptImageSourceProvider));
    } on ImageSourceException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (path == null || !mounted) return;
    setState(() => _imagePath = path);
    await _scanImage(path);
  }

  Future<void> _scanImage(String path) async {
    setState(() {
      _isProcessing = true;
      _scan = null;
      _error = null;
    });
    try {
      final scan = await ref.read(assistantRepositoryProvider).scanReceipt(path);
      if (!mounted) return;
      setState(() => _scan = scan);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _reset() => setState(() {
        _imagePath = null;
        _scan = null;
        _error = null;
      });

  void _review(DraftTransaction draft) => context.push('/assistant/review', extra: ReviewArgs(draft));

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét hóa đơn'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_imagePath == null) _pickerCard(context) else _preview(),
              if (_error != null && _imagePath == null) ...[
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
              ],
              if (_isProcessing) ...[
                const SizedBox(height: 24),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('AI đang đọc và phân tích hóa đơn...', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Có thể mất vài giây', style: AppTypography.caption(context)),
                    ],
                  ),
                ),
              ],
              if (_error != null && _imagePath != null && !_isProcessing) _failure(context, _error!),
              if (scan != null && !_isProcessing) ..._result(context, scan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerCard(BuildContext context) {
    return LiquidGlassCard(
      variant: LiquidGlassVariant.standard,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Center(child: Icon(LucideIcons.scanLine, size: 36, color: AppColors.secondary)),
          ),
          const SizedBox(height: 18),
          Text(
            'Chụp hoặc tải ảnh hóa đơn',
            textAlign: TextAlign.center,
            style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'AI FinMate sẽ trích xuất tên cửa hàng, ngày giờ và tổng số tiền. Bạn rà soát rồi mới lưu.',
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
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
                  onPressed: () => _pick((s) => s.pickFromGallery()),
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
                  onPressed: () => _pick((s) => s.scanBill()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppSpacing.roundedLarge,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.glassBorder(context)),
              borderRadius: AppSpacing.roundedLarge,
            ),
            child: Image.file(
              File(_imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(LucideIcons.imageOff)),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: LiquidGlassIconButton(icon: LucideIcons.rotateCcw, size: 38, tooltip: 'Chọn ảnh khác', onPressed: _reset),
        ),
      ],
    );
  }

  Widget _failure(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: AppTypography.body(context)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _scanImage(_imagePath!), child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  List<Widget> _result(BuildContext context, ReceiptScan scan) {
    if (!scan.success || scan.draft.amountCents == null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  'Không đọc được hóa đơn. Bạn thử chụp rõ hơn hoặc nhập giao dịch bằng tay.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(context),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _reset, child: const Text('Chọn ảnh khác')),
              ],
            ),
          ),
        ),
      ];
    }
    final orders = scan.orders;
    if (orders.length > 1) return [const SizedBox(height: 18), _ordersCard(context, scan)];

    final draft = scan.draft;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final category = categories.where((c) => c.slug == draft.categorySlug).firstOrNull;
    final items = [for (final g in draft.receiptGroups) ...g.items];
    return [
      const SizedBox(height: 18),
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
                    decoration: BoxDecoration(color: AppColors.safe.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.checkCheck, color: AppColors.safe, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.merchantName ?? 'Hóa đơn',
                          style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        if (draft.transactedAt != null)
                          Text(DateFormat('HH:mm - dd/MM/yyyy').format(draft.transactedAt!), style: AppTypography.caption(context)),
                        if (category != null) Text(category.name, style: AppTypography.caption(context)),
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
                    formatVnd(draft.amountCents!),
                    style: AppTypography.displayBalance(context).copyWith(fontSize: 24, color: AppColors.danger, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (draft.needsReview) ...[
                const SizedBox(height: 8),
                Text(
                  'AI chưa chắc chắn về một số chi tiết, bạn kiểm tra kỹ ở bước rà soát.',
                  style: AppTypography.caption(context).copyWith(color: AppColors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 18),
        ZenvestSurfaceSheet(
          title: 'Chi tiết các món hàng',
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              for (final item in items) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.circleDot, size: 10, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.name, style: AppTypography.body(context).copyWith(fontSize: 13.5))),
                      Text(
                        formatVnd(item.amountCents),
                        style: AppTypography.tabular(
                          AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
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
      ],
      const SizedBox(height: 24),
      LiquidGlassPillButton(
        label: 'Rà soát và lưu giao dịch',
        icon: LucideIcons.arrowRight,
        isFullWidth: true,
        onPressed: () => _review(draft),
      ),
    ];
  }

  Widget _ordersCard(BuildContext context, ReceiptScan scan) {
    final cut = scan.incompleteOrders > 0 ? ' Còn ${scan.incompleteOrders} đơn bị cắt ở mép ảnh, hãy chụp thêm phần đó.' : '';
    return ZenvestSurfaceSheet(
      title: 'Tìm thấy ${scan.orders.length} đơn trong ảnh',
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rà soát và lưu từng đơn.$cut', style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          for (final order in scan.orders) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(order.merchantName ?? 'Đơn hàng', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: order.description == null ? null : Text(order.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(order.amountCents == null ? 'Chưa đọc được' : formatVnd(order.amountCents!)),
              onTap: order.amountCents == null ? null : () => _review(order),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
