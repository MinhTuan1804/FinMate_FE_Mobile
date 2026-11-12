import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';

/// Màn H12 & H13: Quản lý Danh mục thu chi (Category Management Screen)
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  int _selectedTab = 0; // 0: Chi tiêu, 1: Thu nhập

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    int selectedColorIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(_selectedTab == 0 ? 'Thêm danh mục chi tiêu' : 'Thêm danh mục thu nhập'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tên danh mục'),
                ),
                const SizedBox(height: 18),
                const Text('Chọn màu đại diện (Pastel Palette):', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(AppColors.chartPalette.length, (idx) {
                    final color = AppColors.chartPalette[idx];
                    final isSelected = selectedColorIndex == idx;
                    return InkWell(
                      onTap: () => setDlgState(() => selectedColorIndex = idx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.white,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã tạo danh mục mới thành công!')),
                  );
                }
              },
              child: const Text('Lưu danh mục'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục thu chi'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('Thêm danh mục'),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented Pill
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLightSubtle.withValues(alpha: 0.7),
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Row(
                  children: [
                    _tabButton('Tất cả', 0),
                    _tabButton('Tự tạo', 1),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              categoriesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => LiquidGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Không thể tải danh mục'),
                      TextButton(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
                data: (categories) {
                  final filtered = _selectedTab == 0
                      ? categories.toList()
                      : categories.where((c) => !c.isSystem).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Chưa có danh mục nào.',
                          style: AppTypography.caption(context),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ...filtered.asMap().entries.map((entry) {
                        final i = entry.key;
                        final cat = entry.value;
                        final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LiquidGlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(LucideIcons.tag, size: 18, color: color),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: AppTypography.body(context).copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.pencil, size: 16),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    final activeBg = AppColors.primaryAction(context);
    final activeFg = AppColors.onPrimaryAction(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: AppSpacing.roundedPill,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? activeFg : AppColors.textPrimary(context),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
