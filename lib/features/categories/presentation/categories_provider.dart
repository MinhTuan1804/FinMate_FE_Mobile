import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';

/// Mọi danh mục của người dùng hiện tại, kể cả danh mục hệ thống đã ẩn (một lần gọi API duy nhất).
/// Chưa đăng nhập thì rỗng và không gọi API. Chỉ màn quản lý danh mục cần dùng trực tiếp để bật lại danh mục đã ẩn.
final allCategoriesProvider = FutureProvider<List<Category>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <Category>[];
  return ref.watch(categoriesRepositoryProvider).getCategories(includeHidden: true);
});

/// Danh mục để CHỌN (giao dịch, ngân sách...): bỏ các danh mục hệ thống người dùng đã ẩn.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final all = await ref.watch(allCategoriesProvider.future);
  return all.where((c) => !c.isHidden).toList();
});

/// Bảng màu của màn thêm/sửa danh mục (admin đổi được ở cấu hình hệ thống). Không tải được (mất mạng, server cũ)
/// thì dùng bảng mặc định: màn hình vẫn dùng được, không báo lỗi vì đây chỉ là gợi ý lựa chọn.
final categoryOptionsProvider = FutureProvider.autoDispose<CategoryOptions>((ref) async {
  try {
    return await ref.watch(categoriesRepositoryProvider).getOptions();
  } catch (_) {
    return CategoryOptions.fallback;
  }
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
  Future<Category> create({
    required String name,
    String? iconName,
    String? color,
    String? kind,
    String? parentCategoryId,
    BigInt? suggestedBudgetCents,
    bool isFavorite = false,
  }) async {
    final created = await repository.createCategory(
      name: name,
      iconName: iconName,
      color: color,
      kind: kind,
      parentCategoryId: parentCategoryId,
      suggestedBudgetCents: suggestedBudgetCents,
      isFavorite: isFavorite,
    );
    ref.invalidate(allCategoriesProvider);
    return created;
  }

  Future<void> update({
    required String id,
    required String name,
    String? iconName,
    String? color,
    String? kind,
    String? parentCategoryId,
    BigInt? suggestedBudgetCents,
    bool? isFavorite,
  }) async {
    await repository.updateCategory(
      id: id,
      name: name,
      iconName: iconName,
      color: color,
      kind: kind,
      parentCategoryId: parentCategoryId,
      suggestedBudgetCents: suggestedBudgetCents,
      isFavorite: isFavorite,
    );
    ref.invalidate(allCategoriesProvider);
  }

  Future<void> setHidden(String id, {required bool hidden}) async {
    await repository.setCategoryHidden(id, hidden: hidden);
    ref.invalidate(allCategoriesProvider);
  }

  Future<void> delete(String id) async {
    await repository.deleteCategory(id);
    ref.invalidate(allCategoriesProvider);
  }
}
