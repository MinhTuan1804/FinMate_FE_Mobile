import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';

/// Danh mục của người dùng hiện tại; chưa đăng nhập thì rỗng và không gọi API
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <Category>[];
  return ref.watch(categoriesRepositoryProvider).getCategories();
});

/// Tạo/sửa/xóa danh mục; mỗi lệnh thành công sẽ làm [categoriesProvider] tải lại
/// (invalidate) nên mọi nơi đang watch danh mục tự cập nhật theo, không cần biết nhau.
final categoriesControllerProvider = Provider<CategoriesController>(
  (ref) => CategoriesController(repository: ref.watch(categoriesRepositoryProvider), ref: ref),
);

class CategoriesController {
  final CategoriesRepository repository;
  final Ref ref;

  CategoriesController({required this.repository, required this.ref});

  /// Lỗi được ném lại cho màn hình; thành công thì danh mục được tải lại ở nơi khác
  Future<Category> create({required String name, String? iconName}) async {
    final created = await repository.createCategory(name: name, iconName: iconName);
    ref.invalidate(categoriesProvider);
    return created;
  }

  Future<void> update({required String id, required String name, String? iconName}) async {
    await repository.updateCategory(id: id, name: name, iconName: iconName);
    ref.invalidate(categoriesProvider);
  }

  Future<void> delete(String id) async {
    await repository.deleteCategory(id);
    ref.invalidate(categoriesProvider);
  }
}
