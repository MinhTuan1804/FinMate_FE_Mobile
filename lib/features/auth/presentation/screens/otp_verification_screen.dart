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

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpKey = GlobalKey<GlassOtpInputState>();
  String _code = '';
  int _countdown = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Register không tự gửi OTP (backend chỉ tạo tài khoản) — màn này phải chủ động
    // gửi mã lần đầu khi mở lên, nếu không người dùng sẽ không nhận được gì cho tới
    // khi hết đếm ngược 60s và tự bấm "Gửi lại mã".
    _sendInitialCode();
  }

  Future<void> _sendInitialCode() async {
    try {
      await ref.read(authControllerProvider.notifier).resendVerification(widget.email);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
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

  Future<void> _verify() async {
    if (_isLoading) return;
    if (_code.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ mã 6 chữ số.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final loggedIn = await ref.read(authControllerProvider.notifier).verifyEmail(widget.email, _code);
      if (!mounted) return;
      // Đã đăng nhập: router tự chuyển sang terms/onboarding/home. Chưa có token: yêu cầu đăng nhập lại.
      if (!loggedIn) {
        context.go('/login', extra: {
          'email': widget.email,
          'notice': 'Email đã được xác thực. Vui lòng đăng nhập để tiếp tục.',
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    try {
      await ref.read(authControllerProvider.notifier).resendVerification(widget.email);
      if (mounted) {
        _otpKey.currentState?.clear();
        _startCountdown();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoading;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: GlassColors.ink),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Xác thực Email', style: GlassTypography.headlineLg()),
                const SizedBox(height: 8),
                Text('Mã xác nhận 6 chữ số đã được gửi tới:\n${widget.email}', style: GlassTypography.bodyMd()),
                const SizedBox(height: 32),

                GlassOtpInput(
                  key: _otpKey,
                  onChanged: (code) => setState(() {
                    _code = code;
                    _error = null;
                  }),
                  onCompleted: (code) => setState(() => _code = code),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck, size: 14, color: GlassColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'FinMate không bao giờ yêu cầu bạn đọc mã OTP qua điện thoại.',
                        style: GlassTypography.bodySm(),
                      ),
                    ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: GlassTypography.bodySm(color: GlassColors.danger)),
                ],

                const SizedBox(height: 24),
                GlassPrimaryButton(label: 'Xác nhận & Tiếp tục', onPressed: _verify, loading: isLoading),

                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _countdown == 0 ? _resend : null,
                    child: Text(
                      _countdown > 0 ? 'Gửi lại mã sau ${_countdown}s' : 'Gửi lại mã xác nhận',
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
