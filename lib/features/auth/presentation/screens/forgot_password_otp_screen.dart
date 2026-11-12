import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_otp_input.dart';

/// Bước 2/3 của luồng khôi phục mật khẩu: nhập mã 6 số đã gửi tới email.
/// Mã chỉ thực sự được server kiểm tra khi gọi /auth/reset-password ở bước sau — sai mã sẽ báo lỗi
/// ở màn Đặt lại mật khẩu, không có API riêng để "xác thực mã" ở bước này.
class ForgotPasswordOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const ForgotPasswordOtpScreen({super.key, required this.email});

  @override
  ConsumerState<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends ConsumerState<ForgotPasswordOtpScreen> {
  final _otpKey = GlobalKey<GlassOtpInputState>();
  String _code = '';
  int _countdown = 60;
  Timer? _timer;
  String? _error;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (_code.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ mã 6 chữ số.');
      return;
    }
    context.push('/reset-password', extra: {'email': widget.email, 'code': _code});
  }

  Future<void> _resend() async {
    if (_countdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(widget.email);
      if (mounted) {
        _otpKey.currentState?.clear();
        _startCountdown();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: GlassColors.ink),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bước 2/3', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor)),
                const SizedBox(height: 8),
                Text('Nhập mã xác thực', style: GlassTypography.headlineLg()),
                const SizedBox(height: 8),
                Text('Mã 6 chữ số đã được gửi tới:\n${widget.email}', style: GlassTypography.bodyMd()),
                const SizedBox(height: 32),
                GlassOtpInput(
                  key: _otpKey,
                  onChanged: (code) => setState(() {
                    _code = code;
                    _error = null;
                  }),
                  onCompleted: (code) => setState(() => _code = code),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: GlassTypography.bodySm(color: GlassColors.danger)),
                ],
                const SizedBox(height: 28),
                GlassPrimaryButton(label: 'Xác nhận & Tiếp tục', onPressed: _continue),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _countdown == 0 ? _resend : null,
                    child: Text(
                      _countdown > 0 ? 'Gửi lại mã sau ${_countdown}s' : 'Gửi lại mã xác thực',
                      style: GlassTypography.bodyMd(
                        color: _countdown == 0 ? GlassColors.slateAnchor : GlassColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
