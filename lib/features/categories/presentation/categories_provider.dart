import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';

/// Danh mục của người dùng hiện tại; chưa đăng nhập thì rỗng và không gọi API
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <Category>[];
  return ref.watch(categoriesRepositoryProvider).getCategories();
});
