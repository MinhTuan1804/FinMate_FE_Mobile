import 'package:flutter/material.dart';
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
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

enum _Tab { all, custom }

/// Màn H12: Danh mục thu & chi (theo Figma). Danh sách thật từ API, gom thành "Danh mục hệ thống" và "Danh mục của bạn";
/// hạn mức hiển thị là hạn mức ngân sách tháng thật của danh mục (nếu đã đặt). Chỉ danh mục tự tạo sửa/xóa được.
/// Tab Chi tiêu/Thu nhập và nhóm cha trong Figma chưa có ở BE nên thay bằng tab Tất cả/Tự tạo.
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  _Tab _tab = _Tab.all;
  String _query = '';

  void _openForm([Category? editing]) => context.push('/profile/categories/form', extra: editing);

  /// Danh mục hệ thống dùng chung nên không sửa tên/biểu tượng; chỉ đặt hạn mức tháng riêng của người dùng (ngân sách theo danh mục).
  /// Ẩn/hiện danh mục hệ thống chỉ cho riêng người dùng này (giao dịch cũ giữ nguyên danh mục).
  Future<void> _setHidden(Category c, bool hidden) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(categoriesControllerProvider).setHidden(c.id, hidden: hidden);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _editLimit(Category c, BigInt? current) async {
    final messenger = ScaffoldMessenger.of(context);
    final limit = await showDialog<BigInt>(context: context, builder: (_) => _LimitDialog(name: c.name, current: current));
    if (limit == null) return;
    try {
      await ref.read(planningControllerProvider.notifier).createOrUpdateBudget(categoryId: c.id, limitAmountCents: limit);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allCategoriesProvider);
    final budgets = ref.watch(planningControllerProvider).valueOrNull?.categoryBudgets ?? const [];
    final limits = {for (final b in budgets) if (b.categoryId != null) b.categoryId!: b.limitAmountCents};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục thu & chi'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [
          IconButton(key: const ValueKey('add-category-top'), tooltip: 'Thêm danh mục', icon: const Icon(LucideIcons.plus), onPressed: _openForm),
        ],
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(allCategoriesProvider.future),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(errorMessage(e), textAlign: TextAlign.center, style: AppTypography.body(context)),
                const SizedBox(height: AppSpacing.lg),
                Center(child: OutlinedButton(onPressed: () => ref.invalidate(allCategoriesProvider), child: const Text('Thử lại'))),
              ],
            ),
            data: (categories) => _content(context, categories, limits),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<Category> everything, Map<String, BigInt> limits) {
    final all = everything.where((c) => !c.isHidden).toList();
    final custom = all.where((c) => !c.isSystem).toList();
    final q = _query.trim().toLowerCase();
    bool match(Category c) => q.isEmpty || c.name.toLowerCase().contains(q);
    final system = _tab == _Tab.custom ? <Category>[] : all.where((c) => c.isSystem && match(c)).toList();
    final mine = custom.where(match).toList();
    final hidden = _tab == _Tab.custom ? <Category>[] : everything.where((c) => c.isHidden && match(c)).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.inset(context, 0.5), borderRadius: AppSpacing.roundedPill),
          child: Row(
            children: [
              _tabButton('Tất cả (${all.length})', _Tab.all),
              _tabButton('Tự tạo (${custom.length})', _Tab.custom),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('category-search'),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm danh mục...',
            prefixIcon: const Icon(LucideIcons.search, size: 16),
            filled: true,
            fillColor: AppColors.inset(context, 0.55),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: AppSpacing.roundedPill, borderSide: BorderSide(color: AppColors.insetBorder(context))),
            enabledBorder: OutlineInputBorder(borderRadius: AppSpacing.roundedPill, borderSide: BorderSide(color: AppColors.insetBorder(context))),
          ),
        ),
        if (system.isEmpty && mine.isEmpty && hidden.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              all.isEmpty ? 'Chưa có danh mục nào.' : (_tab == _Tab.custom && q.isEmpty ? 'Bạn chưa tạo danh mục nào. Bấm "Thêm danh mục mới" để tạo.' : 'Không tìm thấy danh mục phù hợp.'),
              textAlign: TextAlign.center,
              style: AppTypography.body(context),
            ),
          ),
        if (mine.isNotEmpty) ..._group(context, 'Danh mục của bạn', mine, limits),
        if (system.isNotEmpty) ..._group(context, 'Danh mục hệ thống', system, limits),
        if (hidden.isNotEmpty) ..._group(context, 'Đã ẩn', hidden, limits),
        const SizedBox(height: 20),
        LiquidGlassPillButton(
          key: const ValueKey('add-category-bottom'),
          label: 'Thêm danh mục mới',
          icon: LucideIcons.plus,
          isFullWidth: true,
          onPressed: _openForm,
        ),
      ],
    );
  }

  List<Widget> _group(BuildContext context, String title, List<Category> items, Map<String, BigInt> limits) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppTypography.h2(context).copyWith(fontSize: 17, fontWeight: FontWeight.w700))),
            Text('${items.length} DANH MỤC', style: AppTypography.sectionLabel(context)),
          ],
        ),
      ),
      LiquidGlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.textMuted(context).withValues(alpha: 0.18)),
              _row(context, items[i], limits[items[i].id]),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _row(BuildContext context, Category c, BigInt? limit) {
    final editable = !c.isSystem;
    return InkWell(
      key: ValueKey('category-${c.id}'),
      onTap: editable ? () => _openForm(c) : (c.isHidden ? null : () => _editLimit(c, limit)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: (parseHexColor(c.color) ?? AppColors.secondary).withValues(alpha: parseHexColor(c.color) == null ? 0.18 : 0.35), borderRadius: BorderRadius.circular(12)),
              child: Icon(categoryIconFor(c.slug, c.iconName), size: 20, color: parseHexColor(c.color) == null ? AppColors.slateOn(context) : AppColors.textPrimary(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    // Hạn mức thật (ngân sách) ưu tiên; chưa có thì hiện hạn mức GỢI Ý người dùng đã nhập lúc tạo danh mục.
                    limit != null
                        ? 'Hạn mức: ${formatVnd(limit)}/tháng'
                        : (c.suggestedBudgetCents == null ? 'Chưa cài đặt hạn mức' : 'Hạn mức gợi ý: ${formatVnd(c.suggestedBudgetCents!)}/tháng'),
                    style: AppTypography.caption(context).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (c.isFavorite) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(LucideIcons.star, key: ValueKey('favorite-${c.id}'), size: 16, color: AppColors.textMuted(context))),
            Icon(editable ? LucideIcons.chevronRight : LucideIcons.pencil, size: 18, color: AppColors.textMuted(context)),
            // "Khác" là chỗ rơi cuối của phân loại nên không ẩn được.
            if (!editable && (c.isHidden || c.slug != 'other'))
              IconButton(
                key: ValueKey('${c.isHidden ? 'show' : 'hide'}-category-${c.id}'),
                tooltip: c.isHidden ? 'Hiện lại' : 'Ẩn danh mục này',
                visualDensity: VisualDensity.compact,
                icon: Icon(c.isHidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: AppColors.textMuted(context)),
                onPressed: () => _setHidden(c, !c.isHidden),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, _Tab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: selected ? AppColors.activeFill(context) : Colors.transparent, borderRadius: AppSpacing.roundedPill),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: selected ? AppColors.activeFg(context) : AppColors.textPrimary(context), fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitDialog extends StatefulWidget {
  final String name;
  final BigInt? current;
  const _LimitDialog({required this.name, required this.current});

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final _amount = TextEditingController(text: widget.current == null ? '' : formatAmountDigits(widget.current!));
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseAmountInput(_amount.text);
    if (value == null) {
      setState(() => _error = 'Nhập số tiền lớn hơn 0');
    } else {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Hạn mức "${widget.name}"'),
        content: TextField(
          key: const ValueKey('category-limit-input'),
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          autofocus: true,
          decoration: InputDecoration(labelText: 'Hạn mức mỗi tháng (VNĐ)', errorText: _error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(key: const ValueKey('category-limit-save'), onPressed: _submit, child: const Text('Lưu')),
        ],
      );
}
