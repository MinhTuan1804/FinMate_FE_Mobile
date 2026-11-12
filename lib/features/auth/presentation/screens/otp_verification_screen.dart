import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  int _countdown = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _error;

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
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (_isLoading) return;
    if (code.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ mã 6 chữ số.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final loggedIn = await ref
          .read(authControllerProvider.notifier)
          .verifyEmail(widget.email, code);
      if (!mounted) return;
      if (!loggedIn) {
        context.go(
          '/login',
          extra: {
            'email': widget.email,
            'notice': 'Email đã được xác thực. Vui lòng đăng nhập để tiếp tục.',
          },
        );
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
      await ref
          .read(authControllerProvider.notifier)
          .resendVerification(widget.email);
      if (mounted) _startCountdown();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoading;
    final actionColor = AppColors.primaryAction(context);
    final mutedColor = AppColors.textMuted(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: AmbientGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Xác thực Email', style: AppTypography.h1(context)),
                const SizedBox(height: 8),
                Text(
                  'Mã xác nhận 6 chữ số đã được gửi tới:\n${widget.email}',
                  style: AppTypography.body(context).copyWith(
                    color: AppColors.textSecondary(context),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),

                ZenvestSurfaceSheet(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: AppTypography.moneyLarge.copyWith(
                          letterSpacing: 12,
                          color: AppColors.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '------',
                          hintStyle: TextStyle(
                            letterSpacing: 12,
                            color: mutedColor,
                          ),
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: isLoading ? null : _verify,
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimaryAction(context),
                                ),
                              )
                            : const Text(
                                'Xác nhận',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: _countdown == 0 ? _resend : null,
                    child: Text(
                      _countdown > 0
                          ? 'Gửi lại mã sau ${_countdown}s'
                          : 'Gửi lại mã xác nhận',
                      style: TextStyle(
                        color: _countdown == 0 ? actionColor : mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
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
