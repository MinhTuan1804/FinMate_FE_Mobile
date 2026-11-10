import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';

/// Màn quản lý danh mục: tạo mới, đổi tên, xóa. Đơn giản để test nhanh 3 API còn thiếu
/// (create/update/delete) — danh mục hệ thống (isSystem) không cho xóa/sửa trên màn này.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _showForm(BuildContext context, WidgetRef ref, {Category? editing}) async {
    final controller = TextEditingController(text: editing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? 'Danh mục mới' : 'Đổi tên danh mục'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Tên danh mục')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final categories = ref.read(categoriesControllerProvider);
      if (editing == null) {
        await categories.create(name: name);
      } else {
        await categories.update(id: editing.id, name: name);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text('Xóa "${category.name}". Giao dịch đã gán danh mục này sẽ chuyển về chưa phân loại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(categoriesControllerProvider).delete(category.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục'),
        actions: [
          IconButton(
            key: const ValueKey('add-category'),
            tooltip: 'Thêm danh mục',
            onPressed: () => _showForm(context, ref),
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
      body: categoriesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(errorMessage(e), style: AppTypography.body(context))),
        data: (categories) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final category = categories[i];
            return Container(
              key: ValueKey('category-${category.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: AppSpacing.roundedMedium,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: ListTile(
                leading: Icon(categoryIcon(category.slug), color: AppColors.primary),
                title: Text(category.name, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
                subtitle: category.isSystem ? const Text('Danh mục hệ thống') : null,
                trailing: category.isSystem
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('edit-${category.id}'),
                            tooltip: 'Đổi tên',
                            onPressed: () => _showForm(context, ref, editing: category),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            key: ValueKey('delete-${category.id}'),
                            tooltip: 'Xóa',
                            onPressed: () => _delete(context, ref, category),
                            icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
