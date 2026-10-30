import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/config/brand_logo.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Màn hình Chào mừng: Cam kết Zero-Credential & điều khoản được đồng ý ở màn /terms sau khi đăng nhập (BR-01, BR-09, BR-70)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Logo & App Name
              const Center(child: BrandLogo()),
              const SizedBox(height: 24),
              Text(
                'FinMate',
                textAlign: TextAlign.center,
                style: AppTypography.h1(context).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Trợ lý quản lý tài chính cá nhân thông minh\nTự động ghi chép và kiểm soát ngân sách tối ưu',
                textAlign: TextAlign.center,
                style: AppTypography.body(context).copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 3),

              // Banner Cam kết Zero-Credential (BR-09, BR-70)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
                  borderRadius: AppSpacing.roundedMedium,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      size: 22,
                      color: AppColors.safe,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cam kết bảo mật Zero-Credential',
                            style: AppTypography.bodyMedium(context).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'FinMate tuyệt đối không bao giờ yêu cầu mật khẩu Internet Banking, mã PIN hay mã OTP ngân hàng của bạn.',
                            style: AppTypography.caption(context).copyWith(
                              height: 1.35,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Bạn sẽ xem và đồng ý Điều khoản & Chính sách quyền riêng tư ở bước tiếp theo.',
                textAlign: TextAlign.center,
                style: AppTypography.caption(context),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                  elevation: 0,
                ),
                child: const Text(
                  'Đăng nhập với Email',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => context.push('/register'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                ),
                child: const Text(
                  'Tạo tài khoản mới',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
