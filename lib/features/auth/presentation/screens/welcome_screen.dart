import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// a1 — Màn hình Chào mừng: Cam kết Zero-Credential & điều khoản được đồng ý ở màn /terms
/// sau khi đăng nhập (BR-01, BR-09, BR-70).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      showAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: GlassColors.ink,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Center(
                      child: Icon(LucideIcons.wallet, size: 36, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('FinMate', textAlign: TextAlign.center, style: GlassTypography.displayHero()),
                const SizedBox(height: 8),
                Text(
                  'Trợ lý quản lý tài chính cá nhân thông minh\nTự động ghi chép và kiểm soát ngân sách tối ưu',
                  textAlign: TextAlign.center,
                  style: GlassTypography.bodyLg(color: GlassColors.textSecondary).copyWith(height: 1.4),
                ),
                const Spacer(flex: 3),
                GlassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.shieldCheck, size: 22, color: GlassColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cam kết bảo mật Zero-Credential',
                              style: GlassTypography.bodyMd(color: GlassColors.textPrimary)
                                  .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FinMate tuyệt đối không bao giờ yêu cầu mật khẩu Internet Banking, mã PIN hay mã OTP ngân hàng của bạn.',
                              style: GlassTypography.bodySm().copyWith(height: 1.35),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(LucideIcons.lock, size: 13, color: GlassColors.textMuted),
                                const SizedBox(width: 6),
                                Text('Tiêu chuẩn bảo mật ngân hàng 256-bit', style: GlassTypography.bodySm()),
                              ],
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
                  style: GlassTypography.bodySm(),
                ),
                const SizedBox(height: 16),
                GlassPrimaryButton(label: 'Bắt đầu ngay', onPressed: () => context.push('/register')),
                const SizedBox(height: 12),
                GlassGhostButton(label: 'Đã có tài khoản? Đăng nhập', onPressed: () => context.push('/login')),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
