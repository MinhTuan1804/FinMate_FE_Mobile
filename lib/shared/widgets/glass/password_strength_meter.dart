import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

class PasswordStrengthResult {
  final bool hasMinLength;
  final bool hasUpperAndDigit;
  final bool hasSpecialChar;

  const PasswordStrengthResult({
    required this.hasMinLength,
    required this.hasUpperAndDigit,
    required this.hasSpecialChar,
  });

  factory PasswordStrengthResult.of(String password) => PasswordStrengthResult(
        hasMinLength: password.length >= 8,
        hasUpperAndDigit: RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[0-9]').hasMatch(password),
        hasSpecialChar: RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password),
      );

  int get metCount => (hasMinLength ? 1 : 0) + (hasUpperAndDigit ? 1 : 0) + (hasSpecialChar ? 1 : 0);

  String get label => switch (metCount) {
        0 => 'Rất yếu',
        1 => 'Yếu',
        2 => 'Khá mạnh',
        _ => 'Mạnh',
      };

  Color get color => switch (metCount) {
        0 || 1 => GlassColors.danger,
        2 => GlassColors.warning,
        _ => GlassColors.success,
      };
}

/// Thước đo độ mạnh mật khẩu theo thời gian thực (3 đoạn + danh sách tiêu chí), tính từ giá trị
/// thật của ô nhập — không dùng trạng thái tĩnh minh họa như trong mockup.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final result = PasswordStrengthResult.of(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _segment(result.metCount >= 1, result.color)),
            const SizedBox(width: 6),
            Expanded(child: _segment(result.metCount >= 2, result.color)),
            const SizedBox(width: 6),
            Expanded(child: _segment(result.metCount >= 3, result.color)),
            const SizedBox(width: 10),
            Text(result.label, style: GlassTypography.bodySm(color: result.color).copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        _criterion('Tối thiểu 8 ký tự', result.hasMinLength),
        const SizedBox(height: 6),
        _criterion('1 chữ hoa và 1 chữ số', result.hasUpperAndDigit),
        const SizedBox(height: 6),
        _criterion('1 ký tự đặc biệt', result.hasSpecialChar),
      ],
    );
  }

  Widget _segment(bool active, Color color) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? color : GlassColors.secondarySurface,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _criterion(String label, bool met) => Row(
        children: [
          Icon(
            met ? LucideIcons.checkCircle2 : LucideIcons.circle,
            size: 14,
            color: met ? GlassColors.success : GlassColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(label, style: GlassTypography.bodySm(color: met ? GlassColors.textPrimary : GlassColors.textMuted)),
        ],
      );
}
