import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_colors.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Màn H13: Thêm / sửa danh mục (theo Figma): xem trước biểu tượng, tên, loại chi/thu, biểu tượng, màu nhận diện (bảng màu do admin đặt),
/// nhóm cha (danh mục hệ thống), hạn mức ngân sách gợi ý mỗi tháng (chỉ để hiển thị) và "yêu thích". Tất cả lưu ở backend.
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
  late final TextEditingController _budget = TextEditingController(
    text: widget.editing?.suggestedBudgetCents == null ? '' : formatAmountDigits(widget.editing!.suggestedBudgetCents!),
  );
  late String? _icon = categoryIconChoices.containsKey(widget.editing?.iconName) ? widget.editing!.iconName : null;

  /// null = người dùng chưa chọn: tạo mới thì dùng màu đầu bảng, sửa thì giữ như cũ
  late String? _colorHex = widget.editing?.color;
  late String _kind = widget.editing?.kind ?? 'expense';
  late String? _parentId = widget.editing?.parentCategoryId;
  late bool _favorite = widget.editing?.isFavorite ?? false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  /// Màu đang chọn: màu người dùng chọn, hoặc (tạo mới) màu đầu bảng màu
  String? _effectiveColor(CategoryOptions options) => _colorHex ?? (widget.editing == null ? options.palette.firstOrNull?.hex : null);

  Future<void> _save(CategoryOptions options) async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = ref.read(categoriesControllerProvider);
      final editing = widget.editing;
      final budget = _budget.text.trim().isEmpty ? null : parseAmountInput(_budget.text, allowZero: true);
      final color = _effectiveColor(options);
      if (editing == null) {
        await controller.create(
          name: _name.text.trim(),
          iconName: _icon,
          color: color,
          kind: _kind,
          parentCategoryId: _parentId,
          suggestedBudgetCents: budget,
          isFavorite: _favorite,
        );
      } else {
        // Sửa là gửi đủ trạng thái trên màn: bỏ nhóm cha = kNoParentId, bỏ hạn mức = 0.
        await controller.update(
          id: editing.id,
          name: _name.text.trim(),
          iconName: _icon,
          color: color,
          kind: _kind,
          parentCategoryId: _parentId ?? kNoParentId,
          suggestedBudgetCents: budget ?? BigInt.zero,
          isFavorite: _favorite,
        );
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

  void _setKind(String kind) {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _parentId = null; // nhóm cha thuộc đúng loại: đổi loại thì phải chọn lại
    });
  }

  Widget _kindTab(String kind, String label, IconData icon) {
    final selected = _kind == kind;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: ValueKey('category-kind-$kind'),
          onTap: () => _setKind(kind),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: selected ? AppColors.activeFill(context) : Colors.transparent, borderRadius: AppSpacing.roundedPill),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? AppColors.activeFg(context) : AppColors.textPrimary(context)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? AppColors.activeFg(context) : AppColors.textPrimary(context), fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final options = ref.watch(categoryOptionsProvider).valueOrNull ?? CategoryOptions.fallback;
    final selectedHex = _effectiveColor(options);
    final accent = parseHexColor(selectedHex) ?? AppColors.secondary;
    final selectedColorName = options.palette.where((c) => sameHexColor(c.hex, selectedHex)).map((c) => c.name).firstOrNull;
    final parents = (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[]).where((c) => c.isSystem && c.kind == _kind).toList();
    final parentValue = parents.any((c) => c.id == _parentId) ? _parentId : null;

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
                          key: const ValueKey('category-preview'),
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.28),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent, width: 3),
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.inset(context, 0.5), borderRadius: AppSpacing.roundedPill),
                  child: Row(
                    children: [
                      _kindTab('expense', 'Khoản chi tiêu', LucideIcons.arrowDown),
                      _kindTab('income', 'Khoản thu nhập', LucideIcons.arrowUp),
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
                            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: AppSpacing.roundedPill),
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
                const SizedBox(height: 16),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Màu nhận diện', style: AppTypography.h2(context).copyWith(fontSize: 17, fontWeight: FontWeight.w700))),
                          if (selectedColorName != null)
                            Text(selectedColorName, key: const ValueKey('category-color-name'), style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final color in options.palette)
                            Semantics(
                              button: true,
                              selected: sameHexColor(color.hex, selectedHex),
                              label: 'Màu ${color.name}',
                              child: InkWell(
                                key: ValueKey('color-${color.key}'),
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => _colorHex = color.hex),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: parseHexColor(color.hex) ?? AppColors.secondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: sameHexColor(color.hex, selectedHex) ? AppColors.textPrimary(context) : Colors.transparent, width: 2.5),
                                  ),
                                  child: sameHexColor(color.hex, selectedHex) ? const Icon(LucideIcons.check, size: 18, color: Colors.black87) : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Nhóm danh mục cha', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('category-parent-$_kind-${parents.length}'),
                        initialValue: parentValue,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Không chọn nhóm')),
                          for (final parent in parents) DropdownMenuItem<String?>(value: parent.id, child: Text(parent.name)),
                        ],
                        onChanged: (v) => setState(() => _parentId = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Text('Hạn mức ngân sách gợi ý / tháng', style: AppTypography.bodyMedium(context))),
                          Text('Tùy chọn', style: AppTypography.caption(context)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('category-budget'),
                        controller: _budget,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                        decoration: const InputDecoration(hintText: 'Để trống nếu không cần', suffixText: 'VND'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return parseAmountInput(v, allowZero: true) == null ? 'Hạn mức không hợp lệ.' : null;
                        },
                      ),
                      const SizedBox(height: 4),
                      Text('Chỉ để tham khảo, không tự tạo ngân sách.', style: AppTypography.caption(context)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const ValueKey('category-favorite'),
                        contentPadding: EdgeInsets.zero,
                        value: _favorite,
                        onChanged: (v) => setState(() => _favorite = v),
                        title: Text('Đưa vào danh sách yêu thích', style: AppTypography.bodyMedium(context)),
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
                  onPressed: _busy ? () {} : () => _save(options),
                ),
                if (editing != null) ...[
                  const SizedBox(height: 10),
                  AsyncActionBuilder(
                    onPressed: _busy ? null : _delete,
                    builder: (_, onTap, running) => OutlinedButton.icon(
                      key: const ValueKey('category-delete'),
                      onPressed: onTap,
                      icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Xóa danh mục này', style: TextStyle(color: AppColors.danger), maxLines: 1)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                        backgroundColor: AppColors.danger.withValues(alpha: 0.06),
                      ),
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
