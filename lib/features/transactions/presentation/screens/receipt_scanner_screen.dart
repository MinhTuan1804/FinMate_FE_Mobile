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
  ConsumerState<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  String? _imagePath;
  bool _isProcessing = false;
  ReceiptScan? _scan;
  String? _error;

  Future<void> _pick(
    Future<String?> Function(ReceiptImageSource) choose,
  ) async {
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
      final scan = await ref
          .read(assistantRepositoryProvider)
          .scanReceipt(path);
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

  void _review(DraftTransaction draft) =>
      context.push('/assistant/review', extra: ReviewArgs(draft));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cameraBackdrop,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cameraBackdrop, AppColors.surfaceDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(child: _viewfinder(context)),
              _hint(context),
              _bottomPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _cameraButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cameraControl,
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(
                    color: AppColors.onCamera.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.onCamera,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Quét hóa đơn AI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onCamera,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_imagePath != null)
            _cameraButton(
              icon: LucideIcons.rotateCcw,
              tooltip: 'Chọn ảnh khác',
              onPressed: _isProcessing ? null : _reset,
            )
          else
            const SizedBox(width: AppSpacing.minTouchTarget),
        ],
      ),
    );
  }

  Widget _cameraButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.cameraControl,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.onCamera.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? AppColors.onCameraDisabled
                  : AppColors.onCamera,
            ),
          ),
        ),
      ),
    );
  }

  /// Khung ngắm: ảnh hóa đơn trong bốn góc quét, kèm các nhãn AI đọc được đè lên ảnh
  Widget _viewfinder(BuildContext context) {
    final scan = _scan;
    final draft =
        scan != null &&
            scan.success &&
            scan.draft.amountCents != null &&
            scan.orders.length <= 1
        ? scan.draft
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.78,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _imagePath == null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.cameraScrim.withValues(alpha: 0.5),
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.scanLine,
                            size: 48,
                            color: AppColors.onCameraMuted,
                          ),
                        ),
                      )
                    : Image.file(
                        File(_imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            LucideIcons.imageOff,
                            color: AppColors.onCameraMuted,
                          ),
                        ),
                      ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CornersPainter(AppColors.onCamera),
                  ),
                ),
              ),
              if (draft != null && !_isProcessing) ..._tags(draft),
              if (_isProcessing)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ColoredBox(
                      color: AppColors.cameraScrim,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.onCamera,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'AI đang đọc và phân tích hóa đơn...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.onCamera,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Có thể mất vài giây',
                                style: TextStyle(
                                  color: AppColors.onCamera.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nhãn kính nhỏ đè lên ảnh: cửa hàng, ngày, tổng tiền (đọc từ kết quả quét thật)
  List<Widget> _tags(DraftTransaction draft) {
    Widget tag(IconData icon, String text, {bool strong = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: strong
            ? AppColors.secondary.withValues(alpha: 0.92)
            : AppColors.cameraControl,
        borderRadius: AppSpacing.roundedPill,
        border: Border.all(color: AppColors.onCamera.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: strong ? AppColors.primary : AppColors.onCamera,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: strong ? AppColors.primary : AppColors.onCamera,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return [
      Positioned(
        left: 12,
        right: 12,
        top: 12,
        child: ExcludeSemantics(
          child: Row(
            children: [
              if (draft.merchantName != null)
                Flexible(child: tag(LucideIcons.store, draft.merchantName!)),
              const Spacer(),
              if (draft.transactedAt != null)
                tag(
                  LucideIcons.calendar,
                  DateFormat('dd/MM/yyyy').format(draft.transactedAt!),
                ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 16,
        child: ExcludeSemantics(
          child: Align(
            alignment: Alignment.centerLeft,
            child: tag(
              LucideIcons.banknote,
              'Tổng tiền: ${formatVnd(draft.amountCents!)}',
              strong: true,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _hint(BuildContext context) {
    final error = _error;
    final isError = error != null && _imagePath == null;
    final text = isError
        ? error
        : (_imagePath == null
              ? 'Căn chỉnh hóa đơn vào khung hình để AI tự động trích xuất thông tin.'
              : null);
    if (text == null) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cameraControl,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isError
                ? AppColors.danger
                : AppColors.onCamera.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? AppColors.onCamera : AppColors.onCameraMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel(BuildContext context) {
    if (_isProcessing) return const SizedBox(height: 16);
    if (_imagePath == null) return _controls();
    if (_error != null) {
      return _sheet(
        context,
        _messageBody(
          context,
          _error!,
          'Thử lại',
          () => _scanImage(_imagePath!),
        ),
      );
    }
    final scan = _scan;
    if (scan == null) return const SizedBox(height: 16);
    if (!scan.success || scan.draft.amountCents == null) {
      return _sheet(
        context,
        _messageBody(
          context,
          'Không đọc được hóa đơn. Bạn thử chụp rõ hơn hoặc nhập giao dịch bằng tay.',
          'Chọn ảnh khác',
          _reset,
        ),
      );
    }
    if (scan.orders.length > 1) {
      return _sheet(context, _ordersBody(context, scan));
    }
    return _sheet(context, _resultBody(context, scan.draft));
  }

  /// Hàng nút chọn nguồn ảnh khi chưa có ảnh: thư viện và nút tròn lớn (quét/chụp)
  Widget _controls() {
    Widget labelled(Widget button, String label, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button,
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.onCamera,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          labelled(
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.cameraControl,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.onCamera.withValues(alpha: 0.18),
                ),
              ),
              child: const Icon(
                LucideIcons.image,
                size: 22,
                color: AppColors.onCamera,
              ),
            ),
            'Thư viện',
            () => _pick((s) => s.pickFromGallery()),
          ),
          const SizedBox(width: 28),
          labelled(
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onCamera, width: 3),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.onCamera,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
            ),
            'Chụp ảnh',
            () => _pick((s) => s.scanBill()),
          ),
        ],
      ),
    );
  }

  /// Bảng kết quả sáng trượt từ đáy (Figma D4)
  Widget _sheet(BuildContext context, Widget body) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: body,
      ),
    );
  }

  Widget _messageBody(
    BuildContext context,
    String message,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body(context),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onAction,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }

  Widget _resultBody(BuildContext context, DraftTransaction draft) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final category = categories
        .where((c) => c.slug == draft.categorySlug)
        .firstOrNull;
    final itemCount = [for (final g in draft.receiptGroups) ...g.items].length;
    final secondary = AppTypography.caption(context);

    Widget row(IconData icon, String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: secondary.color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.body(context).copyWith(color: secondary.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.scanText,
              size: 16,
              color: AppColors.slateOn(context),
            ),
            const SizedBox(width: 8),
            Text(
              'TRÍCH XUẤT SƠ BỘ',
              style: secondary.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        row(
          LucideIcons.store,
          'Cửa hàng',
          Text(
            draft.merchantName ?? 'Hóa đơn',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        row(
          LucideIcons.banknote,
          'Số tiền',
          Text(
            formatVnd(draft.amountCents!),
            style: AppTypography.tabular(
              AppTypography.h2(
                context,
              ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (category != null)
          row(
            LucideIcons.layoutGrid,
            'Danh mục đề xuất',
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.22),
                borderRadius: AppSpacing.roundedPill,
              ),
              child: Text(
                category.name,
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (draft.transactedAt != null)
          row(
            LucideIcons.clock,
            'Thời gian',
            Text(
              DateFormat('HH:mm - dd/MM/yyyy').format(draft.transactedAt!),
              style: AppTypography.bodyMedium(context),
            ),
          ),
        if (itemCount > 0)
          Text(
            'Gồm $itemCount món hàng, bạn xem chi tiết ở bước rà soát.',
            style: secondary,
          ),
        if (draft.needsReview) ...[
          const SizedBox(height: 8),
          Text(
            'AI chưa chắc chắn về một số chi tiết, bạn kiểm tra kỹ ở bước rà soát.',
            style: secondary.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _review(draft),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primaryAction(context),
            foregroundColor: AppColors.onPrimaryAction(context),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Tiếp tục với kết quả này',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(width: 8),
              Icon(LucideIcons.arrowRight, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ordersBody(BuildContext context, ReceiptScan scan) {
    final cut = scan.incompleteOrders > 0
        ? ' Còn ${scan.incompleteOrders} đơn bị cắt ở mép ảnh, hãy chụp thêm phần đó.'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tìm thấy ${scan.orders.length} đơn trong ảnh',
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Rà soát và lưu từng đơn.$cut',
          style: AppTypography.caption(context),
        ),
        const SizedBox(height: 8),
        for (final order in scan.orders) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              order.merchantName ?? 'Đơn hàng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: order.description == null
                ? null
                : Text(
                    order.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Text(
              order.amountCents == null
                  ? 'Chưa đọc được'
                  : formatVnd(order.amountCents!),
            ),
            onTap: order.amountCents == null ? null : () => _review(order),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

/// Bốn góc khung quét
class _CornersPainter extends CustomPainter {
  const _CornersPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 28.0;
    const r = 20.0;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, len + r)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(len + r, 0)
      ..moveTo(w - len - r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, len + r)
      ..moveTo(w, h - len - r)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - len - r, h)
      ..moveTo(len + r, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - len - r);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}
