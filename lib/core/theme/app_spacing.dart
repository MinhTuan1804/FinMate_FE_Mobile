import 'package:flutter/material.dart';

/// Centralized Spacing & Radius Tokens for FinMate
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Corner Radius Tokens (Quy chuẩn theo taste-skill: 1 hệ radius cố định)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusPill = 999.0;

  static const Radius rSmall = Radius.circular(radiusSmall);
  static const Radius rMedium = Radius.circular(radiusMedium);
  static const Radius rLarge = Radius.circular(radiusLarge);
  static const Radius rPill = Radius.circular(radiusPill);

  static const BorderRadius roundedSmall = BorderRadius.all(rSmall);
  static const BorderRadius roundedMedium = BorderRadius.all(rMedium);
  static const BorderRadius roundedLarge = BorderRadius.all(rLarge);
  static const BorderRadius roundedPill = BorderRadius.all(rPill);
}
