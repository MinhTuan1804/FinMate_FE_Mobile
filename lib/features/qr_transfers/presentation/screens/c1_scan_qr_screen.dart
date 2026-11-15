import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finmate/features/qr_transfers/domain/vietqr_payload.dart';

/// C1 — Quét QR. Camera thật (mobile_scanner), đèn pin (nút ở góc trên) và chọn ảnh từ thư viện để giải mã.
/// Quét hoá đơn là luồng riêng (D4) nên không nằm ở màn này.
class C1ScanQrScreen extends StatefulWidget {
  const C1ScanQrScreen({super.key});

  @override
  State<C1ScanQrScreen> createState() => _C1ScanQrScreenState();
}

class _C1ScanQrScreenState extends State<C1ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final ImagePicker _imagePicker = ImagePicker();
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
          MobileScanner(controller: _controller, onDetect: _onDetect),
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
                Expanded(child: _viewfinder()),
                _quickActions(),
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

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickActionButton(key: const ValueKey('c1-gallery'), icon: LucideIcons.images, label: 'Chọn từ ảnh', onTap: _pickFromGallery),
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
