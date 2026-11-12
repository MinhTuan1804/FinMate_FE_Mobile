import 'package:flutter/material.dart';

/// Bán kính bo góc "Serene Liquid Glass" — lớn hơn hệ [AppSpacing] dùng cho phần còn lại của app,
/// chỉ dùng cho Auth/Onboarding.
class GlassRadius {
  GlassRadius._();

  static const double card = 24.0;
  static const double cardLarge = 28.0;
  static const double hero = 32.0;
  static const double input = 20.0;
  static const double pill = 9999.0;

  static const BorderRadius roundedCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius roundedCardLarge = BorderRadius.all(Radius.circular(cardLarge));
  static const BorderRadius roundedHero = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius roundedInput = BorderRadius.all(Radius.circular(input));
  static const BorderRadius roundedPill = BorderRadius.all(Radius.circular(pill));
}
