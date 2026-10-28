import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Ánh xạ slug danh mục của backend sang icon Lucide (không dùng iconName Material của backend)
IconData categoryIcon(String? slug) {
  switch (slug) {
    case 'food':
      return LucideIcons.utensils;
    case 'transport':
      return LucideIcons.car;
    case 'shopping':
      return LucideIcons.shoppingBag;
    case 'bills':
      return LucideIcons.receipt;
    case 'entertainment':
      return LucideIcons.clapperboard;
    case 'health':
      return LucideIcons.heartPulse;
    case 'education':
      return LucideIcons.graduationCap;
    case 'family':
      return LucideIcons.users;
    case 'housing':
      return LucideIcons.house;
    case 'income':
      return LucideIcons.banknote;
    case 'loan':
      return LucideIcons.handshake;
    default:
      return LucideIcons.tag;
  }
}
