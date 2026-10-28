/// Danh mục giao dịch (GET /categories)
class Category {
  final String id;
  final String name;
  final String slug;
  final String iconName;
  final bool isSystem;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName = '',
    this.isSystem = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        iconName: json['iconName'] as String? ?? '',
        isSystem: json['isSystem'] as bool? ?? true,
      );
}
