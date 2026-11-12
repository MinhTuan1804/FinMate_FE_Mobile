import 'package:flutter/material.dart';

/// Centralized Spacing, Radius, Blur & Motion Tokens for FinMate (Liquid Glass System)
/// Tuân thủ lưới 8pt, vùng chạm tối thiểu 44x44pt, bo góc nhất quán (12 / 16 / 20 / 28 / Pill).
class AppSpacing {
  AppSpacing._();

  // 8pt Grid Spacing Scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Vùng chạm tối thiểu đạt chuẩn WCAG / Apple HIG (44pt) & Material (48dp)
  static const double minTouchTarget = 48.0;

  // Liquid Glass Corner Radius Tokens (12 / 16 / 20 / 28 / 999)
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXl = 28.0;
  static const double radiusPill = 999.0;

  static const Radius rSmall = Radius.circular(radiusSmall);
  static const Radius rMedium = Radius.circular(radiusMedium);
  static const Radius rLarge = Radius.circular(radiusLarge);
  static const Radius rXl = Radius.circular(radiusXl);
  static const Radius rPill = Radius.circular(radiusPill);

  static const BorderRadius roundedSmall = BorderRadius.all(rSmall);
  static const BorderRadius roundedMedium = BorderRadius.all(rMedium);
  static const BorderRadius roundedLarge = BorderRadius.all(rLarge);
  static const BorderRadius roundedXl = BorderRadius.all(rXl);
  static const BorderRadius roundedPill = BorderRadius.all(rPill);

  /// Bo góc cho Bottom Sheet & Sheet Container kiểu Zenvest (28px ở 2 góc trên)
  static const BorderRadius roundedTopSheet = BorderRadius.vertical(
    top: rXl,
  );

  // Liquid Glass Backdrop Blur Sigma Tokens (20–40px theo đặc tả, giới hạn tối đa 3 lớp/màn hình)
  static const double blurSubtle = 16.0;
  static const double blurCard = 24.0; // Tier 1: Card kính
  static const double blurFloating = 34.0; // Tier 2: Bottom Nav, Modal, Bottom Sheet

  // Motion Tokens (Spring mượt 200–350ms, tôn trọng Reduce Motion)
  static const Duration motionFast = Duration(milliseconds: 200);
  static const Duration motionSpring = Duration(milliseconds: 280);
  static const Duration motionPage = Duration(milliseconds: 340);
  static const Curve springCurve = Curves.easeOutBack;
  static const Curve smoothCurve = Curves.easeOutCubic;
}
