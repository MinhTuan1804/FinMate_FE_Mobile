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

/// Bộ icon người dùng chọn khi tạo danh mục (H13). Khóa là chuỗi lưu vào `iconName` của backend.
const categoryIconChoices = <String, IconData>{
  'coffee': LucideIcons.coffee,
  'utensils': LucideIcons.utensils,
  'shopping-bag': LucideIcons.shoppingBag,
  'plane': LucideIcons.plane,
  'gamepad': LucideIcons.gamepad2,
  'car': LucideIcons.car,
  'zap': LucideIcons.zap,
  'pill': LucideIcons.pill,
  'paw': LucideIcons.pawPrint,
  'fuel': LucideIcons.fuel,
  'dumbbell': LucideIcons.dumbbell,
  'smile': LucideIcons.smile,
  'briefcase': LucideIcons.briefcase,
  'gift': LucideIcons.gift,
};

/// Icon của một danh mục: ưu tiên icon người dùng đã chọn (`iconName`), không có thì theo slug của danh mục hệ thống.
IconData categoryIconFor(String? slug, String? iconName) => categoryIconChoices[iconName] ?? categoryIcon(slug);
