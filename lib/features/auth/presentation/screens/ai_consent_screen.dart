import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// a8 — Bước sau khi đồng ý Điều khoản: 2 lựa chọn đồng ý AI riêng biệt
/// (cá nhân hoá vs đóng góp dữ liệu huấn luyện), mỗi lựa chọn ghi qua đúng
/// [ConsentKind] đã có sẵn, không đổi hành vi backend.
class AiConsentScreen extends ConsumerStatefulWidget {
  const AiConsentScreen({super.key});

  @override
  ConsumerState<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends ConsumerState<AiConsentScreen> {
  bool _aiPersonalization = true;
  bool _trainingContribution = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _continue() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(authControllerProvider.notifier);
      // Server tự bật AI khi đồng ý Điều khoản (xem consent.dart); nếu người dùng tắt ở đây thì
      // phải rút lại tường minh, không chỉ đơn giản là "không gọi gì".
      if (_aiPersonalization) {
        await notifier.acceptConsent(ConsentKind.ai);
      } else {
        await notifier.withdrawConsent(ConsentKind.ai);
      }
      if (_trainingContribution) await notifier.acceptConsent(ConsentKind.training);
      if (mounted) context.go('/onboarding');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// "Dùng tính năng cơ bản": rút lại AI (server đã tự bật khi đồng ý Điều khoản) để đúng với lời
  /// hứa "cơ bản", đóng góp dữ liệu vẫn giữ mặc định tắt vì chưa từng được bật.
  Future<void> _skip() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).withdrawConsent(ConsentKind.ai);
      if (mounted) context.go('/onboarding');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trợ lý AI của bạn', style: GlassTypography.headlineLg()),
                const SizedBox(height: 8),
                Text(
                  'FinMate dùng AI để tự động phân loại chi tiêu. Bạn có thể bật/tắt từng phần dưới đây, '
                  'và thay đổi bất cứ lúc nào trong Cá nhân.',
                  style: GlassTypography.bodyMd(),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.sparkles, color: GlassColors.slateAnchor, size: 20),
                          const SizedBox(width: 10),
                          Text('Dữ liệu được dùng làm gì?', style: GlassTypography.headlineSm()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tên món trên hóa đơn và cụm sản phẩm trong tin nhắn/giọng nói (đã bỏ số tiền) được gửi cho '
                        'dịch vụ AI để xếp đúng danh mục.',
                        style: GlassTypography.bodyMd(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck, color: GlassColors.success, size: 20),
                          const SizedBox(width: 10),
                          Text('Cam kết ẩn danh', style: GlassTypography.headlineSm()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Không gửi giá tiền, thông tin tài khoản hay danh tính của bạn cho dịch vụ AI.',
                        style: GlassTypography.bodyMd(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _toggleTile(
                  title: 'Cho phép AI cá nhân hoá lời khuyên tài chính',
                  subtitle: 'Phân loại tự động chi tiêu bằng dịch vụ AI của bên thứ ba.',
                  value: _aiPersonalization,
                  onChanged: (v) => setState(() => _aiPersonalization = v),
                ),
                const SizedBox(height: 14),
                _toggleTile(
                  title: 'Đóng góp dữ liệu ẩn danh để cải thiện mô hình FinMate AI',
                  subtitle: 'Lưu chữ hóa đơn đã ẩn thông tin cá nhân cùng danh mục bạn chọn.',
                  value: _trainingContribution,
                  onChanged: (v) => setState(() => _trainingContribution = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger)),
                ],
                const SizedBox(height: 28),
                GlassPrimaryButton(label: 'Đồng ý & Tiếp tục', onPressed: _continue, loading: _isLoading),
                const SizedBox(height: 12),
                GlassGhostButton(
                  label: 'Bỏ qua bước này (Dùng tính năng cơ bản)',
                  onPressed: _isLoading ? null : _skip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: GlassTypography.bodySm()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: GlassColors.ink,
            inactiveTrackColor: GlassColors.secondarySurface,
          ),
        ],
      ),
    );
  }
}
