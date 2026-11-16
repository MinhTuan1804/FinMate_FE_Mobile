import 'package:finmate/core/format/money.dart';

/// Gửi làm `parentCategoryId` khi sửa danh mục để BỎ nhóm cha (backend: Guid rỗng = bỏ; null = giữ nguyên)
const kNoParentId = '00000000-0000-0000-0000-000000000000';

/// Danh mục giao dịch (GET /categories)
class Category {
  final String id;
  final String name;
  final String slug;
  final String iconName;
  final bool isSystem;

  /// `#RRGGBB` hoặc null (app dùng màu mặc định)
  final String? color;

  /// 'expense' hoặc 'income'
  final String kind;

  /// Nhóm cha: luôn là một danh mục hệ thống
  final String? parentCategoryId;

  /// Hạn mức ngân sách GỢI Ý mỗi tháng (đồng); chỉ để hiển thị, không phải ngân sách
  final BigInt? suggestedBudgetCents;
  final bool isFavorite;

  /// Người dùng đã ẩn danh mục hệ thống này (chỉ có khi tải kèm danh mục đã ẩn)
  final bool isHidden;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName = '',
    this.isSystem = true,
    this.color,
    this.kind = 'expense',
    this.parentCategoryId,
    this.suggestedBudgetCents,
    this.isFavorite = false,
    this.isHidden = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        isSystem: json['isSystem'] as bool? ?? true,
        color: json['color'] as String?,
        kind: json['kind'] as String? ?? 'expense',
        parentCategoryId: json['parentCategoryId'] as String?,
        suggestedBudgetCents: json['suggestedBudgetCents'] == null ? null : parseCents(json['suggestedBudgetCents']),
        isFavorite: json['isFavorite'] as bool? ?? false,
        isHidden: json['isHidden'] as bool? ?? false,
      );
}

/// Một màu trong bảng màu danh mục (cấu hình hệ thống, admin đổi được)
class CategoryColorOption {
  final String key;
  final String hex;
  final String name;

  const CategoryColorOption({required this.key, required this.hex, required this.name});

  factory CategoryColorOption.fromJson(Map<String, dynamic> json) => CategoryColorOption(
        key: json['key'] as String? ?? '',
        hex: json['hex'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// GET /categories/options: bảng màu cho màn thêm/sửa danh mục
class CategoryOptions {
  final List<CategoryColorOption> palette;

  const CategoryOptions(this.palette);

  factory CategoryOptions.fromJson(Map<String, dynamic> json) => CategoryOptions([
        for (final e in (json['palette'] as List? ?? const [])) CategoryColorOption.fromJson(e as Map<String, dynamic>),
      ]);

  /// Dùng khi chưa tải được từ server (mất mạng, server cũ): trùng bảng màu mặc định của backend
  static const fallback = CategoryOptions([
    CategoryColorOption(key: 'coral', hex: '#F4A5A5', name: 'Hồng san hô'),
    CategoryColorOption(key: 'honey', hex: '#F0C8A0', name: 'Cam mật ong'),
    CategoryColorOption(key: 'sky', hex: '#8FB3E0', name: 'Xanh trời'),
    CategoryColorOption(key: 'blush', hex: '#E5AFC4', name: 'Hồng phấn'),
    CategoryColorOption(key: 'mint', hex: '#8EDDB4', name: 'Xanh bạc hà'),
    CategoryColorOption(key: 'lavender', hex: '#D5CBF5', name: 'Tím oải hương'),
    CategoryColorOption(key: 'navy', hex: '#4B5F8F', name: 'Xanh navy'),
    CategoryColorOption(key: 'butter', hex: '#F5E27E', name: 'Vàng bơ'),
  ]);
}
