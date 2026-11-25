import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:finmate/core/permissions/permission_service.dart';
import 'package:finmate/features/groups/domain/join_link.dart';
import 'package:finmate/features/qr_transfers/domain/vietqr_payload.dart';
import 'package:finmate/shared/widgets/permission_prompt.dart';

/// C1 — Quét QR. Camera thật (mobile_scanner), đèn pin (nút ở góc trên) và chọn ảnh từ thư viện để giải mã.
/// Cũng nhận QR mời vào nhóm (`https://finmate.app/join/<mã>`): mở thẳng màn xem trước lời mời.
/// Quét hoá đơn là luồng riêng (D4) nên không nằm ở màn này.
class C1ScanQrScreen extends ConsumerStatefulWidget {
  const C1ScanQrScreen({super.key});

  @override
  ConsumerState<C1ScanQrScreen> createState() => _C1ScanQrScreenState();
}

class _C1ScanQrScreenState extends ConsumerState<C1ScanQrScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final ImagePicker _imagePicker = ImagePicker();
  bool _torchOn = false;
  bool _handled = false;

  /// null = đang kiểm tra quyền camera. Chưa cấp thì không dựng camera mà hiện khối giải thích + nút cấp quyền / mở Cài đặt.
  PermissionState? _camera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCamera(askIfNeeded: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Người dùng vừa bật quyền trong Cài đặt rồi quay lại app: kiểm tra lại để vào thẳng chế độ quét.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _camera != PermissionState.granted) _checkCamera();
  }

  Future<void> _checkCamera({bool askIfNeeded = false}) async {
    final service = ref.read(permissionServiceProvider);
    var state = await service.status(AppPermission.camera);
    if (state == PermissionState.denied && askIfNeeded) state = await service.request(AppPermission.camera);
    if (mounted) setState(() => _camera = state);
  }

  Future<void> _requestCamera() async {
    final state = await ref.read(permissionServiceProvider).request(AppPermission.camera);
    if (mounted) setState(() => _camera = state);
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  void _handleRawValue(String? raw) {
    if (raw == null || raw.isEmpty || _handled) return;
    _handled = true;
    final joinCode = parseGroupJoinLink(raw);
    if (joinCode != null) {
      context.push('/accept-invitation', extra: joinCode).then((_) => _resumeScanning());
      return;
    }
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
    ).then((_) => _resumeScanning());
  }

  /// Quay lại từ màn khác: cho quét tiếp. Chế độ noDuplicates không báo lại cùng một mã đang nằm trong khung hình,
  /// nên phải khởi động lại camera thì lần quét sau mới được nhận.
  Future<void> _resumeScanning() async {
    _handled = false;
    if (!mounted) return;
    try {
      await _controller.stop();
      await _controller.start();
    } catch (_) {
      // Camera không khởi động lại được thì thôi: người dùng vẫn thoát và mở lại màn quét được.
    }
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
    final camera = _camera;
    if (camera != PermissionState.granted) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white, leading: BackButton(onPressed: () => context.pop())),
        body: camera == null
            ? const Center(child: CircularProgressIndicator())
            : PermissionPrompt(
                dark: true,
                icon: LucideIcons.camera,
                title: 'Cần quyền camera để quét QR',
                message: 'FinMate dùng camera để quét mã QR chuyển khoản và mã mời vào nhóm. Hãy bật quyền này nếu muốn dùng chức năng quét.',
                state: camera,
                onRequest: _requestCamera,
                onOpenSettings: () => ref.read(permissionServiceProvider).openSettings(),
              ),
      );
    }
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
    // Khung vuông to theo bề ngang màn hình (tối đa 340, chừa chỗ cho dòng hướng dẫn) để không bị trống ở máy cao
    return LayoutBuilder(
      builder: (context, c) {
        final side = (c.maxWidth * 0.78).clamp(200.0, 340.0).clamp(0.0, c.maxHeight - 80);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                ),
              ),
              const SizedBox(height: 20),
              _glassPill(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text(
                  'Căn chỉnh mã VietQR, VNPAY hoặc FinMate vào khung',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickActionButton(key: const ValueKey('c1-gallery'), icon: LucideIcons.images, label: 'Chọn từ ảnh', onTap: _pickFromGallery),
          _quickActionButton(key: const ValueKey('c1-history'), icon: LucideIcons.history, label: 'Gần đây', onTap: () => context.push('/qr-transfers/history')),
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
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
