import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// G6 — Tạo/sửa ngân sách (theo Figma). [budget] null = tạo mới; có = sửa hạn mức (phạm vi/danh mục giữ nguyên).
/// Mốc cảnh báo chỉ ĐỌC từ ngưỡng thật của người dùng. Gợi ý nhanh, chu kỳ tuần/tùy chỉnh, "AI tự cân chỉnh",
/// "Độ chuẩn xác" và thông báo đẩy riêng từng ngân sách chưa có ở BE nên không hiển thị.
class BudgetFormScreen extends ConsumerStatefulWidget {
  final BudgetEntity? budget;
  const BudgetFormScreen({super.key, this.budget});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  late final TextEditingController _limit =
      TextEditingController(text: widget.budget == null ? '' : formatAmountDigits(widget.budget!.limitAmountCents));
  late bool _total;
  String? _categoryId;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final planning = ref.read(planningControllerProvider).valueOrNull;
    // Người dùng mới chưa có ngân sách nào thì mặc định đặt ngân sách tổng
    _total = widget.budget?.isTotal ?? (planning != null && planning.overallBudget == null && planning.categoryBudgets.isEmpty);
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _limit.text = widget.budget == null ? '' : formatAmountDigits(widget.budget!.limitAmountCents);
        _categoryId = null;
        _error = null;
      });

  Future<void> _save() async {
    final limit = parseAmountInput(_limit.text);
    if (limit == null) return setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
    if (!_editing && !_total && _categoryId == null) return setState(() => _error = 'Vui lòng chọn danh mục');

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(planningControllerProvider.notifier)
          .createOrUpdateBudget(categoryId: _editing ? widget.budget!.categoryId : (_total ? null : _categoryId), limitAmountCents: limit);
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu ngân sách')));
      if (mounted) router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limit = parseAmountInput(_limit.text);
    final thresholds = ref.watch(alertThresholdsControllerProvider).valueOrNull;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(
          context,
          title: _editing ? 'Sửa ngân sách' : 'Thiết lập ngân sách',
          actions: [
            TextButton(
              onPressed: _saving ? null : _reset,
              child: Text('Đặt lại', style: GlassTypography.bodySm(color: GlassColors.slateAnchor).copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _scope(),
                    const SizedBox(height: 14),
                    _amount(),
                    if (thresholds != null) ...[
                      const SizedBox(height: 14),
                      _thresholds(thresholds.t1Pct, thresholds.t2Pct, limit),
                    ],
                  ],
                ),
              ),
              GlassBottomDock(
                actions: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: GlassPrimaryButton(
                          key: const ValueKey('budget-save'),
                          label: limit == null ? 'Lưu ngân sách' : 'Lưu ngân sách (${formatVnd(limit)})',
                          icon: LucideIcons.check,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          key: const ValueKey('budget-cancel'),
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: _saving ? null : () => context.pop(),
                          child: Text('Hủy bỏ', style: GlassTypography.bodyMd(color: GlassColors.textMuted)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GlassTypography.labelCaps(color: GlassColors.textSecondary));

  Widget _scope() {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final used = ref.watch(planningControllerProvider).valueOrNull?.categoryBudgets.map((b) => b.categoryId).toSet() ?? const <String?>{};
    final free = categories.where((c) => !used.contains(c.id)).toList();

    return GlassCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('PHẠM VI ÁP DỤNG'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: GlassColors.secondarySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GlassColors.fieldBorder),
            ),
            child: Row(
              children: [
                Expanded(child: _segment('Tất cả chi tiêu', LucideIcons.layoutGrid, _total, () => setState(() => _total = true))),
                Expanded(child: _segment('Theo danh mục', LucideIcons.tag, !_total, () => setState(() => _total = false))),
              ],
            ),
          ),
          if (!_total) ...[
            const SizedBox(height: 12),
            if (_editing)
              _categoryTile(widget.budget!.category, null, true, null)
            else if (free.isEmpty)
              Text('Không còn danh mục nào chưa có ngân sách.', style: GlassTypography.bodyMd())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in free)
                    _categoryTile(c.name, c.slug, _categoryId == c.id, () => setState(() {
                          _categoryId = c.id;
                          _error = null;
                        }), key: ValueKey('budget-cat-${c.id}')),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _segment(String label, IconData icon, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(48),
        // khoá phạm vi khi sửa: không đổi được ngân sách tổng <-> danh mục
        onTap: _editing ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? GlassColors.activeFill : Colors.transparent,
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: selected ? GlassColors.activeBorder : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? GlassColors.activeFg : GlassColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GlassTypography.bodySm(color: selected ? GlassColors.activeFg : GlassColors.textSecondary)
                      .copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(String name, String? slug, bool selected, VoidCallback? onTap, {Key? key}) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: name,
      child: InkWell(
        key: key,
        borderRadius: GlassRadius.roundedPill,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? GlassColors.activeFill : GlassColors.fieldFill,
            borderRadius: GlassRadius.roundedPill,
            border: Border.all(color: selected ? GlassColors.activeBorder : GlassColors.fieldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(categoryIcon(slug), size: 16, color: selected ? GlassColors.activeFg : GlassColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GlassTypography.bodyMd(color: selected ? GlassColors.activeFg : GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amount() {
    return GlassCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label('HẠN MỨC DỰ KIẾN')),
              Text('VND (₫)', style: GlassTypography.labelCaps()),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: GlassColors.fieldFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GlassColors.fieldBorder),
            ),
            child: TextField(
              key: const ValueKey('budget-limit-input'),
              controller: _limit,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              onChanged: (_) => setState(() => _error = null),
              style: GlassTypography.displayHero().copyWith(fontSize: 26),
              cursorColor: GlassColors.slateAnchor,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: GlassTypography.displayHero(color: GlassColors.textMuted).copyWith(fontSize: 26),
                suffixText: '₫',
                suffixStyle: GlassTypography.displayHero(color: GlassColors.textSecondary).copyWith(fontSize: 26),
                semanticCounterText: 'Hạn mức chi tiêu (VNĐ)',
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, key: const ValueKey('budget-error'), style: GlassTypography.bodySm(color: GlassColors.danger)),
            ),
        ],
      ),
    );
  }

  /// Chỉ đọc: ngưỡng cảnh báo thật của người dùng (chỉnh ở màn Ngưỡng cảnh báo), ví dụ bằng tiền tính từ hạn mức đang nhập.
  Widget _thresholds(int t1, int t2, BigInt? limit) {
    Widget row(IconData icon, Color color, String title, int pct) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                limit == null ? '$pct%' : '$pct% · ${formatVnd(limit * BigInt.from(pct) ~/ BigInt.from(100))}',
                textAlign: TextAlign.right,
                style: GlassTypography.labelNumeric().copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Ngưỡng cảnh báo', style: GlassTypography.headlineSm())),
          const SizedBox(height: 4),
          Text('Áp dụng ngưỡng cá nhân của bạn cho ngân sách này.', style: GlassTypography.bodySm()),
          const SizedBox(height: 12),
          row(LucideIcons.bellRing, GlassColors.warning, 'Mốc 1: Cảnh báo sớm', t1),
          const SizedBox(height: 8),
          row(LucideIcons.triangleAlert, GlassColors.danger, 'Mốc 2: Báo động', t2),
        ],
      ),
    );
  }
}
