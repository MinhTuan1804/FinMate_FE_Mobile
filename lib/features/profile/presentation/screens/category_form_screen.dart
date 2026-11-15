import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';

/// Màn H13: Thêm / sửa danh mục (theo Figma). BE chỉ lưu tên và icon của danh mục; màu nhận diện, loại thu/chi,
/// nhóm cha, hạn mức gợi ý và "yêu thích" trong Figma chưa có ở BE nên không hiển thị.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.editing});

  /// null = tạo mới; khác null = sửa danh mục tự tạo này.
  final Category? editing;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.editing?.name ?? '');
  late String? _icon = categoryIconChoices.containsKey(widget.editing?.iconName) ? widget.editing!.iconName : null;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = ref.read(categoriesControllerProvider);
      final editing = widget.editing;
      if (editing == null) {
        await controller.create(name: _name.text.trim(), iconName: _icon);
      } else {
        await controller.update(id: editing.id, name: _name.text.trim(), iconName: _icon);
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(editing == null ? 'Đã thêm danh mục.' : 'Đã lưu danh mục.')));
      context.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Xóa "${editing.name}"?'),
        content: const Text('Danh mục sẽ bị xóa. Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Giữ lại')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(categoriesControllerProvider).delete(editing.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa danh mục.')));
      context.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final accent = AppColors.secondary;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing == null ? 'Thêm danh mục mới' : 'Sửa danh mục'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [TextButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Hủy'))],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withValues(alpha: 0.5), width: 3),
                          ),
                          child: Icon(categoryIconFor(editing?.slug, _icon), size: 36, color: AppColors.textPrimary(context)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(child: Text('BẢN XEM TRƯỚC BIỂU TƯỢNG', style: AppTypography.sectionLabel(context))),
                      const SizedBox(height: 16),
                      Text('Tên danh mục *', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('category-name'),
                        controller: _name,
                        maxLength: 60,
                        decoration: const InputDecoration(hintText: 'Ví dụ: Cà phê & Gặp gỡ', prefixIcon: Icon(LucideIcons.pencil, size: 18), counterText: ''),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên danh mục.' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Chọn biểu tượng', style: AppTypography.h2(context).copyWith(fontSize: 17, fontWeight: FontWeight.w700))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), borderRadius: AppSpacing.roundedPill),
                            child: Text('${categoryIconChoices.length} mẫu', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slateOn(context))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final entry in categoryIconChoices.entries)
                            Semantics(
                              button: true,
                              selected: _icon == entry.key,
                              label: 'Biểu tượng ${entry.key}',
                              child: InkWell(
                                key: ValueKey('icon-${entry.key}'),
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _icon = entry.key),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.inset(context, 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _icon == entry.key ? AppColors.textPrimary(context) : Colors.transparent, width: 2),
                                  ),
                                  child: Icon(entry.value, size: 22, color: AppColors.textPrimary(context)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LiquidGlassPillButton(
                  key: const ValueKey('category-save'),
                  label: _busy ? 'Đang lưu...' : 'Lưu danh mục',
                  icon: LucideIcons.save,
                  isFullWidth: true,
                  onPressed: _busy ? () {} : _save,
                ),
                if (editing != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('category-delete'),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                    label: const Text('Xóa danh mục này', style: TextStyle(color: AppColors.danger)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                      backgroundColor: AppColors.danger.withValues(alpha: 0.06),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
