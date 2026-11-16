import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(apiClient: ref.watch(apiClientProvider)),
);

class CategoriesRepository {
  final ApiClient apiClient;

  CategoriesRepository({required this.apiClient});

  /// [includeHidden] true: kèm danh mục hệ thống người dùng đã ẩn (chỉ màn quản lý danh mục cần).
  Future<List<Category>> getCategories({bool includeHidden = false}) async {
    final response = await apiClient.get(
      '/api/v1/categories',
      queryParameters: includeHidden ? {'includeHidden': true} : null,
      fromJsonT: (json) => (json as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// PUT /categories/{id}/hidden: ẩn/hiện danh mục hệ thống cho riêng người dùng này.
  Future<void> setCategoryHidden(String id, {required bool hidden}) =>
      apiClient.put('/api/v1/categories/$id/hidden', data: {'hidden': hidden}, fromJsonT: (_) => null);

  /// Bảng màu cho màn thêm/sửa danh mục (GET /categories/options)
  Future<CategoryOptions> getOptions() async {
    final response = await apiClient.get(
      '/api/v1/categories/options',
      fromJsonT: (json) => CategoryOptions.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? CategoryOptions.fallback;
  }

  /// Tạo danh mục tùy chỉnh (POST /categories). Trường không dùng thì không gửi.
  Future<Category> createCategory({
    required String name,
    String? iconName,
    String? color,
    String? kind,
    String? parentCategoryId,
    BigInt? suggestedBudgetCents,
    bool isFavorite = false,
  }) async {
    final response = await apiClient.post(
      '/api/v1/categories',
      data: {
        'name': name,
        if (iconName != null) 'iconName': iconName,
        if (color != null) 'color': color,
        if (kind != null) 'kind': kind,
        if (parentCategoryId != null) 'parentCategoryId': parentCategoryId,
        if (suggestedBudgetCents != null) 'suggestedBudgetCents': suggestedBudgetCents.toInt(),
        if (isFavorite) 'isFavorite': true,
      },
      fromJsonT: (json) => Category.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Sửa danh mục (PATCH /categories/{id}). Các trường mới: null = giữ nguyên;
  /// [kNoParentId] = bỏ nhóm cha; [suggestedBudgetCents] = 0 = bỏ hạn mức gợi ý.
  Future<Category> updateCategory({
    required String id,
    required String name,
    String? iconName,
    String? color,
    String? kind,
    String? parentCategoryId,
    BigInt? suggestedBudgetCents,
    bool? isFavorite,
  }) async {
    final response = await apiClient.patch(
      '/api/v1/categories/$id',
      data: {
        'name': name,
        if (iconName != null) 'iconName': iconName,
        if (color != null) 'color': color,
        if (kind != null) 'kind': kind,
        if (parentCategoryId != null) 'parentCategoryId': parentCategoryId,
        if (suggestedBudgetCents != null) 'suggestedBudgetCents': suggestedBudgetCents.toInt(),
        if (isFavorite != null) 'isFavorite': isFavorite,
      },
      fromJsonT: (json) => Category.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Xóa danh mục (DELETE /categories/{id})
  Future<void> deleteCategory(String id) => apiClient.delete('/api/v1/categories/$id');
}
