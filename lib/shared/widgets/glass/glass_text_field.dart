import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Ô nhập kính mờ dùng chung cho Auth/Onboarding (DESIGN.md, mục Input Fields).
class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;

  /// Bật để thêm nút ẩn/hiện mật khẩu tự động.
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? suffixIcon;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  const GlassTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.enabled = true,
    this.inputFormatters,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      inputFormatters: widget.inputFormatters,
      style: GlassTypography.bodyLg(),
      decoration: InputDecoration(
        isDense: false,
        hintText: widget.hintText,
        hintStyle: GlassTypography.bodyLg(color: GlassColors.textMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20, color: GlassColors.textMuted)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_obscure ? LucideIcons.eyeOff : LucideIcons.eye, size: 20, color: GlassColors.textMuted),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffixIcon,
        border: OutlineInputBorder(
          borderRadius: GlassRadius.roundedInput,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: GlassRadius.roundedInput,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: GlassRadius.roundedInput,
          borderSide: const BorderSide(color: GlassColors.accentSkyBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: GlassRadius.roundedInput,
          borderSide: const BorderSide(color: GlassColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: GlassRadius.roundedInput,
          borderSide: const BorderSide(color: GlassColors.danger, width: 1.5),
        ),
      ),
    );

    if (widget.label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label!, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
