import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';

/// Các biến thể độ sâu của hệ thống Liquid Glass (3 tầng: Nền -> Card kính -> Lớp nổi)
enum LiquidGlassVariant {
  /// Tầng 1: Card kính tiêu chuẩn (blur 24px, tint 72%, viền 1px + top highlight)
  standard,

  /// Tầng 1 (Hero): Thẻ kính khúc xạ ánh sáng kiểu Zenvest (blush #E8B2C4 + peach #F3C6A8 + sky #7CA9D6)
  iridescentHero,

  /// Tầng 1.5 (Sheet): Khung danh sách bo góc 28px (chứa các dòng giao dịch bên trong mà không lặp blur)
  sheetContainer,

  /// Tầng 2 (Floating): Lớp nổi như Bottom Nav, Modal, Bottom Sheet, Toast (blur 34px, bóng sâu mềm)
  floating,

  /// Biến thể nhẹ không dùng BackdropFilter (dùng cho item trong ListView cuộn dài để đạt 60fps tuyệt đối)
  subtle,
}

/// Nền khí quyển (Tier 0 Canvas) lấy cảm hứng từ Zenvest (Ảnh 2) & Serene Glass FinTech (Ảnh 1).
/// Tự động bọc trong [RepaintBoundary] để cache trên GPU, không vẽ lại khi cuộn nội dung.
class AmbientGlassBackground extends StatelessWidget {
  const AmbientGlassBackground({
    super.key,
    required this.child,
    this.showIridescentBlobs = true,
  });

  final Widget child;
  final bool showIridescentBlobs;

  @override
  Widget build(BuildContext context) {
    final glass = LiquidGlassTheme.of(context);
    final isDark = glass.isDark;

    if (glass.reduceTransparency || !showIridescentBlobs) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: glass.canvasGradient),
            child: CustomPaint(
              painter: _AmbientMeshPainter(isDark: isDark),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientMeshPainter extends CustomPainter {
  const _AmbientMeshPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Tầng mây trời Zenvest ở nửa trên màn hình (Sky-Mist Header Wash)
    final topSkyWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? <Color>[
                const Color(0xFF16243E).withValues(alpha: 0.65),
                const Color(0xFF0F172A).withValues(alpha: 0.20),
                Colors.transparent,
              ]
            : <Color>[
                const Color(0xFFC9DDF3).withValues(alpha: 0.72),
                const Color(0xFFDCE9F7).withValues(alpha: 0.45),
                Colors.transparent,
              ],
        stops: const <double>[0.0, 0.36, 0.68],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topSkyWash);

    // Quầng mây trắng sáng mềm ở góc trên phải (giống đám mây sau chữ Welcome to Zenvest)
    final cloudRightPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          (isDark ? AppColors.secondary : Colors.white)
              .withValues(alpha: isDark ? 0.14 : 0.62),
          (isDark ? AppColors.secondary : Colors.white).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.82, size.height * 0.15),
          radius: size.width * 0.52,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.15),
      size.width * 0.52,
      cloudRightPaint,
    );

    // Vệt mây Serene Sky Blue (#7CA9D6) ở góc trên trái
    final skyPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.secondary.withValues(alpha: isDark ? 0.16 : 0.30),
          AppColors.secondary.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.10),
          radius: size.width * 0.60,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.10),
      size.width * 0.60,
      skyPaint,
    );

    // Vệt phấn hồng Dusty Rose (#E8B2C4) dịu ở trung tâm phải (phía sau Hero Card)
    final rosePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.tertiary.withValues(alpha: isDark ? 0.12 : 0.24),
          AppColors.tertiary.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.72, size.height * 0.30),
          radius: size.width * 0.52,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.30),
      size.width * 0.52,
      rosePaint,
    );

    // Vệt cam đào ấm (#F3C6A8) nhẹ ở giữa màn hình
    final warmPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.accentWarm.withValues(alpha: isDark ? 0.08 : 0.18),
          AppColors.accentWarm.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.30, size.height * 0.42),
          radius: size.width * 0.50,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.30, size.height * 0.42),
      size.width * 0.50,
      warmPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientMeshPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Thẻ Liquid Glass chuẩn mực với viền 1px, inner highlight cạnh trên, bóng nhiều lớp mềm,
/// hiệu ứng spring mượt khi nhấn và fallback tự động khi bật Reduce Transparency.
class LiquidGlassCard extends StatefulWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius,
    this.variant = LiquidGlassVariant.standard,
    this.enableBlur,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final LiquidGlassVariant variant;
  final bool? enableBlur;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final String? semanticLabel;

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  bool _pressed = false;

  BorderRadius _resolveRadius() {
    if (widget.borderRadius != null) return widget.borderRadius!;
    return switch (widget.variant) {
      LiquidGlassVariant.iridescentHero => AppSpacing.roundedXl,
      LiquidGlassVariant.sheetContainer => AppSpacing.roundedXl,
      LiquidGlassVariant.floating => AppSpacing.roundedXl,
      LiquidGlassVariant.standard => AppSpacing.roundedLarge,
      LiquidGlassVariant.subtle => AppSpacing.roundedMedium,
    };
  }

  double _resolveBlurSigma() {
    return switch (widget.variant) {
      LiquidGlassVariant.floating => AppSpacing.blurFloating,
      LiquidGlassVariant.iridescentHero => AppSpacing.blurCard,
      LiquidGlassVariant.sheetContainer => AppSpacing.blurCard,
      LiquidGlassVariant.standard => AppSpacing.blurCard,
      LiquidGlassVariant.subtle => 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final glass = LiquidGlassTheme.of(context);
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = _resolveRadius();
    final sigma = _resolveBlurSigma();
    final shouldBlur = (widget.enableBlur ?? (widget.variant != LiquidGlassVariant.subtle)) &&
        !glass.reduceTransparency &&
        sigma > 0;

    final Color resolvedFill = widget.backgroundColor ??
        (glass.reduceTransparency
            ? (widget.variant == LiquidGlassVariant.floating ||
                    widget.variant == LiquidGlassVariant.sheetContainer
                ? glass.solidElevatedFallbackFill
                : glass.solidFallbackFill)
            : switch (widget.variant) {
                LiquidGlassVariant.floating => glass.glassElevatedFill,
                LiquidGlassVariant.sheetContainer => glass.glassElevatedFill,
                LiquidGlassVariant.subtle => glass.glassSubtleFill,
                LiquidGlassVariant.iridescentHero => glass.glassFill,
                LiquidGlassVariant.standard => glass.glassFill,
              });

    final Color resolvedBorder = widget.borderColor ?? glass.glassBorder;
    final List<BoxShadow> resolvedShadows = switch (widget.variant) {
      LiquidGlassVariant.floating => glass.floatingShadows,
      LiquidGlassVariant.iridescentHero => glass.floatingShadows,
      LiquidGlassVariant.sheetContainer => glass.cardShadows,
      LiquidGlassVariant.standard => glass.cardShadows,
      LiquidGlassVariant.subtle => const <BoxShadow>[],
    };

    Widget surface = Container(
      decoration: BoxDecoration(
        color: widget.variant == LiquidGlassVariant.iridescentHero &&
                widget.backgroundColor == null &&
                !glass.reduceTransparency
            ? null
            : resolvedFill,
        gradient: widget.variant == LiquidGlassVariant.iridescentHero &&
                widget.backgroundColor == null &&
                !glass.reduceTransparency
            ? glass.heroIridescentGradient
            : null,
        borderRadius: radius,
        border: Border.all(color: resolvedBorder, width: 1.0),
      ),
      child: Stack(
        children: <Widget>[
          if (widget.variant == LiquidGlassVariant.iridescentHero &&
              !glass.reduceTransparency)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ZenvestIridescentWavePainter(isDark: glass.isDark),
                ),
              ),
            ),
          // Inner Specular Highlight ở cạnh trên (1px mảnh lấp lánh như kính thật)
          if (!glass.reduceTransparency)
            Positioned(
              top: 0,
              left: 14,
              right: 14,
              height: 1.2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        glass.glassHighlight.withValues(alpha: 0.0),
                        glass.glassHighlight,
                        glass.glassHighlight.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Hiệu ứng ánh sáng lướt nhẹ khi nhấn (Specular Press Sweep)
          if (_pressed && !disableAnimations)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withValues(alpha: glass.isDark ? 0.10 : 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: widget.padding,
            child: Material(
              type: MaterialType.transparency,
              child: widget.child,
            ),
          ),
        ],
      ),
    );

    if (shouldBlur) {
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: surface,
        ),
      );
    } else {
      surface = ClipRRect(
        borderRadius: radius,
        child: surface,
      );
    }

    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: resolvedShadows,
      ),
      child: surface,
    );

    if (widget.onTap != null) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (!disableAnimations) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (_pressed) setState(() => _pressed = false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed && !disableAnimations ? 0.985 : 1.0,
          duration: disableAnimations ? Duration.zero : AppSpacing.motionFast,
          curve: AppSpacing.smoothCurve,
          child: surface,
        ),
      );
    }

    if (widget.semanticLabel != null) {
      surface = Semantics(
        label: widget.semanticLabel,
        button: widget.onTap != null,
        child: surface,
      );
    }

    if (widget.margin != null) {
      surface = Padding(padding: widget.margin!, child: surface);
    }

    return surface;
  }
}

/// Vẽ các cánh hoa lụa khúc xạ ánh sáng mềm ở góc dưới bên phải thẻ Balance/Hero giống hệt thẻ Zenvest (Ảnh 2 & 3).
class _ZenvestIridescentWavePainter extends CustomPainter {
  const _ZenvestIridescentWavePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Quầng sáng hồng phấn - đào ấm ở góc phải dưới
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.76, 0.48),
        radius: 0.90,
        colors: <Color>[
          AppColors.tertiary.withValues(alpha: isDark ? 0.32 : 0.58),
          AppColors.accentWarm.withValues(alpha: isDark ? 0.22 : 0.45),
          AppColors.secondary.withValues(alpha: isDark ? 0.16 : 0.26),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.36, 0.72, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, glowPaint);

    // 2. Cánh hoa lụa ngoài cùng (Lavender Sky -> Blush Pink)
    final outerPetal = Path()
      ..moveTo(size.width * 0.46, size.height)
      ..cubicTo(
        size.width * 0.52,
        size.height * 0.44,
        size.width * 0.76,
        size.height * 0.12,
        size.width * 1.04,
        size.height * 0.22,
      )
      ..lineTo(size.width * 1.04, size.height)
      ..close();

    final outerPetalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
          AppColors.secondary.withValues(alpha: isDark ? 0.20 : 0.34),
          AppColors.tertiary.withValues(alpha: isDark ? 0.28 : 0.48),
        ],
      ).createShader(rect);
    canvas.drawPath(outerPetal, outerPetalPaint);

    // 3. Cánh hoa lụa giữa (Golden Peach -> Rose)
    final midPetal = Path()
      ..moveTo(size.width * 0.56, size.height)
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.54,
        size.width * 0.84,
        size.height * 0.28,
        size.width * 1.05,
        size.height * 0.48,
      )
      ..lineTo(size.width * 1.05, size.height)
      ..close();

    final midPetalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.accentWarm.withValues(alpha: isDark ? 0.26 : 0.56),
          AppColors.tertiary.withValues(alpha: isDark ? 0.34 : 0.62),
          const Color(0xFFD88CA8).withValues(alpha: isDark ? 0.24 : 0.46),
        ],
      ).createShader(rect);
    canvas.drawPath(midPetal, midPetalPaint);

    // 4. Đường gân sáng mảnh (Specular silk crease lines)
    final creasePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: isDark ? 0.28 : 0.78),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);

    final crease1 = Path()
      ..moveTo(size.width * 0.52, size.height * 0.96)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.38,
        size.width * 1.02,
        size.height * 0.32,
      );
    final crease2 = Path()
      ..moveTo(size.width * 0.64, size.height * 0.98)
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.52,
        size.width * 1.02,
        size.height * 0.58,
      );
    canvas.drawPath(crease1, creasePaint);
    canvas.drawPath(crease2, creasePaint);
  }

  @override
  bool shouldRepaint(covariant _ZenvestIridescentWavePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Khung xếp lớp thẻ Hero kiểu Zenvest (Ảnh 3):
/// - Thanh chỉ báo dọc mảnh bên trái (3.5 x 18px)
/// - Thẻ kính phụ lấp ló ở cạnh phải (Peeking Secondary Glass Card)
/// - Thẻ Hero chính nổi phía trước
class ZenvestHeroDeck extends StatelessWidget {
  const ZenvestHeroDeck({
    super.key,
    required this.child,
    this.peekBadgeText = 'VND',
    this.showIndicator = true,
  });

  final Widget child;
  final String peekBadgeText;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: <Widget>[
        // Thẻ kính thứ 2 lấp ló bên phải giống hệt Zenvest
        Positioned(
          top: 10,
          bottom: 10,
          right: 0,
          width: 56,
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? <Color>[
                            const Color(0xFF1A2942).withValues(alpha: 0.72),
                            const Color(0xFF132238).withValues(alpha: 0.58),
                          ]
                        : <Color>[
                            const Color(0xFFE4F0FC).withValues(alpha: 0.88),
                            const Color(0xFFD9F2EA).withValues(alpha: 0.78),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.18 : 0.04,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 22,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.32),
                      borderRadius: AppSpacing.roundedPill,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Thanh chỉ báo dọc mảnh bên trái giống Zenvest
        if (showIndicator)
          Positioned(
            left: 0,
            bottom: 22,
            child: IgnorePointer(
              child: Container(
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.secondary.withValues(alpha: 0.55)
                      : AppColors.textMutedLight.withValues(alpha: 0.45),
                  borderRadius: AppSpacing.roundedPill,
                ),
              ),
            ),
          ),
        // Thẻ Hero chính
        Padding(
          padding: EdgeInsets.only(
            left: showIndicator ? 8 : 0,
            right: 14,
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Nút viên thuốc kính trắng nổi (Frosted White Action Pill) giống hàng "Send ↗  Received ↙  ⋮" của Zenvest.
class ZenvestActionPill extends StatelessWidget {
  const ZenvestActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.trailingIcon,
    this.leadingIcon,
    this.isActive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bgColor = isActive
        ? (isDark ? AppColors.secondary : AppColors.primary)
        : (isDark
            ? AppColors.surfaceDarkElevated.withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.86));
    final fgColor = isActive
        ? (isDark ? AppColors.primary : Colors.white)
        : AppColors.textPrimary(context);
    final borderColor = isActive
        ? Colors.transparent
        : (isDark
            ? AppColors.borderDark
            : Colors.white.withValues(alpha: 0.95));

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedPill,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: bgColor,
          shape: StadiumBorder(
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (leadingIcon != null) ...<Widget>[
                    Icon(leadingIcon, size: 14, color: fgColor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (trailingIcon != null) ...<Widget>[
                    const SizedBox(width: 5),
                    Icon(
                      trailingIcon,
                      size: 13,
                      color: isActive ? fgColor : AppColors.textSecondary(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Khung Sheet kính trắng nâng cao ("Sheet-on-Sky" Architecture) của Zenvest.
/// Có thanh nắm kéo (drag handle) ở chính giữa đỉnh sheet và tuỳ chọn thanh tiêu đề căn giữa.
class ZenvestSurfaceSheet extends StatelessWidget {
  const ZenvestSurfaceSheet({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 22),
    this.margin,
    this.showDragHandle = true,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    Widget sheet = Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121D31).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? AppColors.borderDark
              : Colors.white.withValues(alpha: 0.96),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0.08 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showDragHandle) ...<Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFD5DFEC),
                      borderRadius: AppSpacing.roundedPill,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (title != null || leading != null || trailing != null) ...<Widget>[
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: leading,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              child,
            ],
          ),
        ),
      ),
    );

    if (margin != null) {
      sheet = Padding(padding: margin!, child: sheet);
    }
    return sheet;
  }
}

/// Dòng giao dịch/hạng mục chuẩn Zenvest (Ảnh 3):
/// - Trái: Icon tròn 44x44 nền dịu
/// - Giữa: Tên đậm + Phụ đề (Danh mục • ↻ Thời gian)
/// - Phải: Số tiền đậm + Nhãn loại giao dịch có màu ở dưới (Income xanh / Expense đỏ / Transfer xanh đá)
class ZenvestTransactionTile extends StatelessWidget {
  const ZenvestTransactionTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.categoryLabel,
    required this.timeLabel,
    required this.amountText,
    required this.amountColor,
    required this.typeLabel,
    required this.typeColor,
    this.onTap,
    this.badgeWidget,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String categoryLabel;
  final String timeLabel;
  final String amountText;
  final Color amountColor;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback? onTap;
  final Widget? badgeWidget;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? iconColor.withValues(alpha: 0.16)
                    : iconColor.withValues(alpha: 0.11),
                border: Border.all(
                  color: iconColor.withValues(alpha: isDark ? 0.28 : 0.18),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (badgeWidget != null) ...<Widget>[
                        const SizedBox(width: 6),
                        badgeWidget!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                      Icon(
                        LucideIcons.refreshCw,
                        size: 10,
                        color: AppColors.textMuted(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: amountColor,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kiểu nút Pill đồng bộ với bảng mẫu "Serene Glass FinTech" (Ảnh 1)
enum LiquidGlassButtonStyle {
  /// Nút chính (#111827 ở Light Mode, #7CA9D6 ở Dark Mode)
  primary,

  /// Nút phụ nền kính sáng (#E6EEF8 ở Light Mode)
  secondary,

  /// Nút đảo màu (#1E293B Slate)
  inverted,

  /// Nút viền mảnh 1px
  outlined,

  /// Nút cảnh báo nguy hiểm (#DC2626)
  danger,
}

/// Nút bấm hình viên thuốc (Pill Button) chuẩn Liquid Glass với vùng chạm >= 48dp.
class LiquidGlassPillButton extends StatelessWidget {
  const LiquidGlassPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.style = LiquidGlassButtonStyle.primary,
    this.isFullWidth = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final LiquidGlassButtonStyle style;
  final bool isFullWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final (Color bg, Color fg, Color border) = switch (style) {
      LiquidGlassButtonStyle.primary => (
          isDark ? AppColors.secondary : AppColors.primary,
          isDark ? AppColors.primary : AppColors.surfaceLightElevated,
          Colors.transparent,
        ),
      LiquidGlassButtonStyle.secondary => (
          isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          isDark ? AppColors.borderDark : AppColors.glassBorderLight,
        ),
      LiquidGlassButtonStyle.inverted => (
          AppColors.primaryHover,
          AppColors.surfaceLightElevated,
          AppColors.borderDark,
        ),
      LiquidGlassButtonStyle.outlined => (
          isDark ? AppColors.glassFillSubtleDark : AppColors.glassFillSubtleLight,
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      LiquidGlassButtonStyle.danger => (
          AppColors.danger,
          AppColors.surfaceLightElevated,
          Colors.transparent,
        ),
    };

    final content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: compact ? 16 : 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: 6),
          Icon(trailingIcon, size: compact ? 15 : 17, color: fg),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? 44.0 : AppSpacing.minTouchTarget,
        minWidth: isFullWidth ? double.infinity : 0,
      ),
      child: Material(
        color: onPressed == null ? bg.withValues(alpha: 0.45) : bg,
        shape: StadiumBorder(
          side: BorderSide(color: border, width: 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.lg,
              vertical: compact ? 10 : 12,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Nút icon tròn chuẩn Serene Glass FinTech (Ảnh 1 góc dưới phải & Ảnh 2 nút +/bell).
/// Đảm bảo vùng chạm tối thiểu 48x48dp.
class LiquidGlassIconButton extends StatelessWidget {
  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style = LiquidGlassButtonStyle.secondary,
    this.size = 44.0,
    this.iconSize = 20.0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final LiquidGlassButtonStyle style;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final (Color bg, Color fg, Color border) = switch (style) {
      LiquidGlassButtonStyle.primary => (
          isDark ? AppColors.secondary : AppColors.primary,
          isDark ? AppColors.primary : AppColors.surfaceLightElevated,
          Colors.transparent,
        ),
      LiquidGlassButtonStyle.secondary => (
          isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLight,
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          isDark ? AppColors.borderDark : AppColors.glassBorderLight,
        ),
      LiquidGlassButtonStyle.inverted => (
          AppColors.slateAction,
          AppColors.surfaceLightElevated,
          Colors.transparent,
        ),
      LiquidGlassButtonStyle.outlined => (
          Colors.transparent,
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      LiquidGlassButtonStyle.danger => (
          AppColors.danger,
          AppColors.surfaceLightElevated,
          Colors.transparent,
        ),
    };

    Widget button = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppSpacing.minTouchTarget,
        minHeight: AppSpacing.minTouchTarget,
      ),
      child: Center(
        child: Material(
          color: bg,
          shape: CircleBorder(side: BorderSide(color: border, width: 1)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: fg),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Thanh tiến trình dạng viên thuốc mảnh (6-8px) từ bảng mẫu Serene Glass FinTech (Ảnh 1).
class LiquidGlassProgressBar extends StatelessWidget {
  const LiquidGlassProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 7.0,
  });

  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final clamped = value.clamp(0.0, 1.0);
    final trackColor = backgroundColor ??
        (isDark
            ? AppColors.surfaceDarkElevated
            : AppColors.surfaceLightSubtle);
    final fillColor = color ?? AppColors.primaryAction(context);

    return ClipRRect(
      borderRadius: AppSpacing.roundedPill,
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: clamped,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(fillColor),
          borderRadius: AppSpacing.roundedPill,
        ),
      ),
    );
  }
}
