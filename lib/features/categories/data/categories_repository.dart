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

  Future<List<Category>> getCategories() async {
    final response = await apiClient.get(
      '/api/v1/categories',
      fromJsonT: (json) => (json as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Tạo danh mục tùy chỉnh (POST /categories)
  Future<Category> createCategory({required String name, String? iconName}) async {
    final response = await apiClient.post(
      '/api/v1/categories',
      data: {'name': name, if (iconName != null) 'iconName': iconName},
      fromJsonT: (json) => Category.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Đổi tên/icon danh mục (PATCH /categories/{id})
  Future<Category> updateCategory({required String id, required String name, String? iconName}) async {
    final response = await apiClient.patch(
      '/api/v1/categories/$id',
      data: {'name': name, if (iconName != null) 'iconName': iconName},
      fromJsonT: (json) => Category.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Xóa danh mục (DELETE /categories/{id})
  Future<void> deleteCategory(String id) => apiClient.delete('/api/v1/categories/$id');
}
