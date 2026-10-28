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
}
