import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';

/// Màn quét mã VietQR của người nhận. Quét được thì sang màn xác nhận số tiền và chọn ngân hàng gửi; mã không đọc được hiện lý do bằng thanh thông báo rồi quét tiếp. Camera bị từ chối hay máy không có camera
/// thì có lối NHẬP TAY (chọn ngân hàng + gõ số tài khoản) để người dùng không bị kẹt.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);

  /// Đang xử lý một mã: các khung hình camera tiếp theo (trước khi camera kịp dừng) không được xử lý lần hai.
  bool _handling = false;
  DateTime? _lastErrorAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handling = true;
    try {
      final data = parseVietQr(raw);
      await _openTransfer(data);
    } on VietQrParseException catch (error) {
      _showParseError(error.message);
    } finally {
      _handling = false;
    }
  }

  /// Cùng một mã hỏng hiện ra liên tục theo từng khung hình: chỉ báo lại sau vài giây để không nháy thông báo.
  void _showParseError(String message) {
    final now = DateTime.now();
    if (_lastErrorAt != null && now.difference(_lastErrorAt!) < const Duration(seconds: 3)) return;
    _lastErrorAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openTransfer(VietQrData? data) async {
    await _controller.stop();
    if (!mounted) return;
    await context.push('/qr-transfer', extra: data);
    if (mounted) await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraUnavailable(error: error, onManual: () => _openTransfer(null)),
          ),
          const IgnorePointer(child: _ScanFrame()),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    _RoundAction(icon: LucideIcons.arrowLeft, label: 'Quay lại', onPressed: () => context.pop()),
                    const Spacer(),
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, _) {
                        final on = state.torchState == TorchState.on;
                        return _RoundAction(
                          icon: on ? LucideIcons.flashlightOff : LucideIcons.flashlight,
                          label: on ? 'Tắt đèn pin' : 'Bật đèn pin',
                          onPressed: state.torchState == TorchState.unavailable ? null : _controller.toggleTorch,
                        );
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _RoundAction(icon: LucideIcons.history, label: 'Lịch sử quét QR', onPressed: () => context.push('/qr-history')),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _HintPill(text: 'Đưa mã QR chuyển khoản của người nhận vào khung'),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => _openTransfer(null),
                      icon: const Icon(LucideIcons.keyboard, size: 18),
                      label: const Text('Nhập số tài khoản'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), minimumSize: const Size(0, 48)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung ngắm hình vuông bo góc ở giữa màn hình.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: AppSpacing.roundedLarge),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: AppSpacing.roundedMedium),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}

/// Nút tròn trên nền camera: vùng chạm 48, có nhãn trợ năng và gợi ý khi nhấn giữ.
class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        fixedSize: const Size(48, 48),
      ),
    );
  }
}

/// Thay cho màn đen mặc định khi camera không dùng được. Chỉ hướng dẫn và mở lối nhập tay; không tự xin lại quyền.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error, required this.onManual});

  final MobileScannerException error;
  final VoidCallback onManual;

  String get _message {
    final code = error.errorCode.name.toLowerCase();
    if (code.contains('permission')) {
      return 'FinMate chưa được cấp quyền camera.\n\nVào Cài đặt > Ứng dụng > FinMate > Quyền > Camera để cấp quyền, hoặc nhập số tài khoản bên dưới.';
    }
    if (code.contains('unsupported')) return 'Máy này không có camera dùng được để quét.\n\nHãy nhập số tài khoản bên dưới.';
    return 'Không mở được camera (${error.errorCode.name}).\n\nHãy nhập số tài khoản bên dưới.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleAlert, color: Colors.white, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(_message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(onPressed: onManual, icon: const Icon(LucideIcons.keyboard, size: 18), label: const Text('Nhập số tài khoản')),
        ],
      ),
    );
  }
}
