import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/planning/data/planning_repository.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Khóa nhận diện một hũ cụ thể trong [jarsProvider] (dùng cho `.family`).
class JarKey {
  final String userMethodId;
  final String jarKey;

  const JarKey({required this.userMethodId, required this.jarKey});

  @override
  bool operator ==(Object other) =>
      other is JarKey && other.userMethodId == userMethodId && other.jarKey == jarKey;

  @override
  int get hashCode => Object.hash(userMethodId, jarKey);
}

/// Ngân sách của các danh mục thuộc hũ này (lọc từ GET /budgets đã có — không gọi API mới).
/// Nối category qua slug: JarCategoryEntity.slug -> Category.slug -> Category.id -> BudgetEntity.categoryId.
final jarCategoryBudgetsProvider = FutureProvider.autoDispose.family<List<BudgetEntity>, JarKey>((ref, key) async {
  final sets = await ref.watch(jarsProvider.future);
  final jarSet = sets.where((s) => s.userMethodId == key.userMethodId).firstOrNull;
  final jar = jarSet?.jars.where((j) => j.key == key.jarKey).firstOrNull;
  if (jar == null || jar.categories.isEmpty) return const [];

  final categories = await ref.watch(categoriesProvider.future);
  final slugs = jar.categories.map((c) => c.slug).toSet();
  final categoryIds = categories.where((c) => slugs.contains(c.slug)).map((c) => c.id).toSet();
  if (categoryIds.isEmpty) return const [];

  final now = DateTime.now();
  final result = await ref.watch(planningRepositoryProvider).getBudgets(month: now.month, year: now.year);
  return result.categories.where((b) => b.categoryId != null && categoryIds.contains(b.categoryId)).toList();
});

/// Giao dịch gần đây của các danh mục thuộc hũ: BE chỉ lọc theo 1 categoryId mỗi lần, nên gọi
/// nhiều lần (một lần/danh mục) rồi merge + sort theo ngày giảm dần, cắt về [limit] mục.
final jarTransactionsProvider = FutureProvider.autoDispose.family<List<TransactionEntity>, JarKey>((ref, key) async {
  const limit = 10;
  final sets = await ref.watch(jarsProvider.future);
  final jarSet = sets.where((s) => s.userMethodId == key.userMethodId).firstOrNull;
  final jar = jarSet?.jars.where((j) => j.key == key.jarKey).firstOrNull;
  if (jar == null || jar.categories.isEmpty) return const [];

  final categories = await ref.watch(categoriesProvider.future);
  final slugs = jar.categories.map((c) => c.slug).toSet();
  final categoryIds = categories.where((c) => slugs.contains(c.slug)).map((c) => c.id).toList();
  if (categoryIds.isEmpty) return const [];

  final repository = ref.watch(transactionRepositoryProvider);
  final merged = <TransactionEntity>[];
  for (final categoryId in categoryIds) {
    final page = await repository.getTransactions(categoryId: categoryId, limit: limit);
    merged.addAll(page.items);
  }
  merged.sort((a, b) => b.date.compareTo(a.date));
  return merged.take(limit).toList();
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
