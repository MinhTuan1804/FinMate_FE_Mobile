import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finmate/features/qr_transfers/domain/vietqr_payload.dart';

enum _ScanMode { qr, invoice }

/// C1 — Quét QR. Camera thật (mobile_scanner), đèn pin, chọn ảnh từ thư viện để giải mã, và
/// toggle "Quét QR"/"Quét hoá đơn" theo quyết định sản phẩm đã ghi trong
/// NAVIGATION_FLOW_AND_ROADMAP.md (không có trong thiết kế Stitch của C1). "Quét hoá đơn" chưa
/// có luồng thật (D4, thuộc Luồng 3) nên chỉ hiện trạng thái "Sắp có", không dẫn tới màn chết.
class C1ScanQrScreen extends StatefulWidget {
  const C1ScanQrScreen({super.key});

  @override
  State<C1ScanQrScreen> createState() => _C1ScanQrScreenState();
}

class _C1ScanQrScreenState extends State<C1ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final ImagePicker _imagePicker = ImagePicker();
  _ScanMode _mode = _ScanMode.qr;
  bool _torchOn = false;
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  void _handleRawValue(String? raw) {
    if (raw == null || raw.isEmpty || _handled) return;
    _handled = true;
    final payload = parseVietQrPayload(raw);
    context.push(
      '/qr-transfers/confirm',
      extra: {
        'receiverBankBin': payload.bankBin,
        'receiverAccountNumber': payload.accountNumber,
        'receiverName': payload.beneficiaryName,
        'amountCents': payload.amountCents,
        'message': payload.message,
      },
    ).then((_) => _handled = false);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      _handleRawValue(barcode.rawValue);
      if (_handled) break;
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final capture = await _controller.analyzeImage(file.path);
    if (capture != null && capture.barcodes.isNotEmpty) {
      _handleRawValue(capture.barcodes.first.rawValue);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy mã QR trong ảnh đã chọn.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_mode == _ScanMode.qr)
            MobileScanner(controller: _controller, onDetect: _onDetect)
          else
            const ColoredBox(color: Colors.black),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.55)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                const SizedBox(height: 8),
                _modeToggle(),
                Expanded(
                  child: _mode == _ScanMode.qr ? _viewfinder() : _invoiceComingSoon(),
                ),
                if (_mode == _ScanMode.qr) _quickActions(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassPill({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: _glassPill(
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
            ),
          ),
          Text('Giao dịch QR', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const ValueKey('c1-history'),
                onTap: () => context.push('/qr-transfers/history'),
                child: _glassPill(
                  child: const Icon(LucideIcons.history, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _toggleTorch,
                child: _glassPill(
                  child: Icon(_torchOn ? LucideIcons.zap : LucideIcons.zapOff, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _glassPill(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modeSegment('Quét QR', _ScanMode.qr),
            _modeSegment('Quét hoá đơn', _ScanMode.invoice),
          ],
        ),
      ),
    );
  }

  Widget _modeSegment(String label, _ScanMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      key: ValueKey('c1-mode-${mode.name}'),
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
          ),
          const SizedBox(height: 20),
          _glassPill(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: const Text(
              'Căn chỉnh mã VietQR, VNPAY hoặc FinMate vào khung',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceComingSoon() {
    // TODO(Luồng 3 D4): thay bằng luồng quét hoá đơn thật khi D4 có — hiện BE/FE chưa có.
    return Center(
      child: _glassPill(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt, color: Colors.white, size: 32),
            SizedBox(height: 10),
            Text('Sắp có', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(height: 4),
            Text(
              'Quét hoá đơn giấy đang được phát triển.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickActionButton(key: const ValueKey('c1-torch'), icon: _torchOn ? LucideIcons.zap : LucideIcons.zapOff, label: 'Đèn Flash', onTap: _toggleTorch),
          _quickActionButton(key: const ValueKey('c1-gallery'), icon: LucideIcons.images, label: 'Chọn từ ảnh', onTap: _pickFromGallery),
          _quickActionButton(
            key: const ValueKey('c1-my-qr'),
            icon: LucideIcons.qrCode,
            label: 'Mã QR của tôi',
            onTap: () {}, // Chưa có màn hiển thị QR nhận tiền của chính mình — để chỗ, không làm gì.
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({required Key key, required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _glassPill(child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
