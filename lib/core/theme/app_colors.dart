import 'package:flutter/material.dart';

/// Centralized Design Token Colors for FinMate
/// Neo-Fintech Minimalist Palette (Chống AI Slop: không gradient tím-xanh, không màu bừa bãi)
class AppColors {
  AppColors._();

  // Dark OLED Palette (Mặc định)
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF131C2E);
  static const Color surfaceDarkElevated = Color(0xFF1E293B);
  static const Color borderDark = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)

  // Light Clean Paper Palette
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightSubtle = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0x14000000); // rgba(0, 0, 0, 0.08)

  // Brand & Semantic Colors
  static const Color primary = Color(0xFF2563EB); // Trust Blue
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF3B82F6);

  // Financial States
  static const Color safe = Color(0xFF10B981); // Emerald: Thu nhập & Ngân sách < 70%
  static const Color warning = Color(0xFFF59E0B); // Amber: Ngưỡng cảnh báo 70-89%
  static const Color danger = Color(0xFFEF4444); // Crimson: Chi tiêu & Ngưỡng nguy hiểm >= 90%
  static const Color transfer = Color(0xFF6366F1); // Indigo: Chuyển khoản nội bộ (không tính thu/chi)
  static const Color expense = danger;
  static const Color income = safe;

  // Text Neutral Tokens
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);
}
