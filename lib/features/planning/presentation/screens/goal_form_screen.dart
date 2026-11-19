import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

const _invalidAmount = 'Vui lòng nhập số tiền hợp lệ';

/// G3 — Tạo/sửa mục tiêu tiết kiệm ([goal] null = tạo mới). Có xem trước tính khả thi qua BE.
class GoalFormScreen extends ConsumerStatefulWidget {
  final SavingsGoalEntity? goal;

  const GoalFormScreen({super.key, this.goal});

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  late final _name = TextEditingController(text: widget.goal?.title ?? '');
  late final _target = TextEditingController(
    text: widget.goal == null
        ? ''
        : formatAmountDigits(widget.goal!.targetAmountCents),
  );
  late DateTime? _deadline = widget.goal?.targetDate;
  String? _error;
  GoalFeasibilityEntity? _feasibility;
  bool _feasibilityChecked = false;
  bool _checking = false;
  bool _saving = false;

  bool get _editing => widget.goal != null;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline != null && _deadline!.isAfter(now)
          ? _deadline!
          : now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
        _feasibilityChecked = false;
      });
    }
  }

  Future<void> _checkFeasibility() async {
    final target = parseAmountInput(_target.text);
    if (target == null || _deadline == null) {
      setState(
        () => _error = target == null
            ? _invalidAmount
            : 'Vui lòng chọn hạn chót để xem khả thi',
      );
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(planningControllerProvider.notifier)
          .previewFeasibility(targetCents: target, deadline: _deadline!);
      if (!mounted) return;
      setState(() {
        _feasibility = result;
        _feasibilityChecked = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final target = parseAmountInput(_target.text);
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên mục tiêu');
      return;
    }
    if (target == null) {
      setState(() => _error = _invalidAmount);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(planningControllerProvider.notifier);
    try {
      if (_editing) {
        await controller.updateGoal(
          id: widget.goal!.id,
          name: name,
          targetCents: target,
          deadline: _deadline,
        );
      } else {
        await controller.createSavingsGoal(
          title: name,
          targetAmountCents: target,
          targetDate: _deadline,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: GlassColors.danger,
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _editing ? 'Đã lưu mục tiêu' : 'Đã tạo mục tiêu tiết kiệm',
        ),
      ),
    );
    final popped = await navigator.maybePop();
    if (!popped && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(
          context,
          title: _editing ? 'Sửa mục tiêu' : 'Tạo mục tiêu mới',
          actions: [
            TextButton(
              key: const ValueKey('cancel-form'),
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(
                'Hủy',
                style: GlassTypography.bodyMd(color: GlassColors.textSecondary),
              ),
            ),
          ],
        ),
        bottomNavigationBar: GlassBottomDock(
          actions: [
            GlassPrimaryButton(
              key: const ValueKey('save-goal'),
              label: 'Lưu mục tiêu',
              icon: LucideIcons.circleCheck,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Tên mục tiêu tích lũy'),
                    const SizedBox(height: 8),
                    _FieldBox(
                      child: TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        style: GlassTypography.headlineSm(),
                        decoration: _bareDecoration('Ví dụ: Quỹ du lịch'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FieldBox(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                child: _FieldLabel('Số tiền mục tiêu'),
                              ),
                              Text(
                                'VNĐ',
                                style: GlassTypography.bodySm(
                                  color: GlassColors.slateAnchor,
                                ).copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _target,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    ThousandsSeparatorInputFormatter(),
                                  ],
                                  onChanged: (_) => setState(
                                    () => _feasibilityChecked = false,
                                  ),
                                  style: GlassTypography.displayHero().copyWith(
                                    fontSize: 28,
                                  ),
                                  decoration: _bareDecoration(
                                    '0',
                                    hintStyle: GlassTypography.displayHero(
                                      color: GlassColors.textMuted,
                                    ).copyWith(fontSize: 28),
                                  ),
                                ),
                              ),
                              Text(
                                '₫',
                                style: GlassTypography.headlineSm(
                                  color: GlassColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DateTile(
                      deadline: _deadline,
                      onTap: _pickDate,
                      onClear: _deadline == null
                          ? null
                          : () => setState(() {
                              _deadline = null;
                              _feasibilityChecked = false;
                            }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _FeasibilityCard(
                checking: _checking,
                checked: _feasibilityChecked,
                feasibility: _feasibility,
                onCheck: _checkFeasibility,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: GlassTypography.bodyMd(color: GlassColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _bareDecoration(String hint, {TextStyle? hintStyle}) =>
    InputDecoration(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintText: hint,
      hintStyle:
          hintStyle ?? GlassTypography.headlineSm(color: GlassColors.textMuted),
    );

/// Nhãn viết hoa nhỏ phía trên ô nhập (theo Figma G3).
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GlassTypography.labelCaps(color: GlassColors.textSecondary),
  );
}

/// Ô nhập bo 16 nền kính nhạt (Figma G3), không viền đậm.
class _FieldBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _FieldBox({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: GlassColors.fieldFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GlassColors.fieldBorder),
    ),
    child: child,
  );
}

class _DateTile extends StatelessWidget {
  final DateTime? deadline;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({required this.deadline, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final d = deadline;
    final text = d == null
        ? 'Chọn hạn chót (tùy chọn)'
        : DateFormat('dd/MM/yyyy').format(d);
    final now = DateTime.now();
    final days = d == null
        ? null
        : DateTime(
            d.year,
            d.month,
            d.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('pick-deadline'),
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: GlassColors.secondarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.calendar,
                        size: 18,
                        color: GlassColors.slateAnchor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Ngày dự kiến hoàn thành'),
                          const SizedBox(height: 2),
                          Text(
                            text,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: GlassTypography.bodyLg(
                              color: d == null
                                  ? GlassColors.textMuted
                                  : GlassColors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (days != null && days >= 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: GlassColors.secondarySurface,
                                borderRadius: GlassRadius.roundedPill,
                              ),
                              child: Text(
                                'còn ~$days ngày',
                                maxLines: 1,
                                style: GlassTypography.bodySm(
                                  color: GlassColors.slateAnchor,
                                ).copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Bỏ hạn chót',
              icon: Icon(LucideIcons.x, size: 18, color: GlassColors.textMuted),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

/// Khối "Khả thi AI": chỉ hiện số liệu BE trả về sau khi người dùng bấm xem trước.
class _FeasibilityCard extends StatelessWidget {
  final bool checking;
  final bool checked;
  final GoalFeasibilityEntity? feasibility;
  final VoidCallback onCheck;

  const _FeasibilityCard({
    required this.checking,
    required this.checked,
    required this.feasibility,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final f = feasibility;
    final infeasible = f?.isFeasible == false;
    final color = infeasible ? GlassColors.danger : GlassColors.success;

    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: GlassColors.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 14,
                  color: GlassColors.onInk,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khả thi AI', style: GlassTypography.headlineSm()),
                    Text(
                      '(FinMate Intelligence)',
                      style: GlassTypography.bodySm(),
                    ),
                  ],
                ),
              ),
              // Chỉ hiện kết luận khả thi do BE trả về, không bịa phần trăm
              if (checked && f?.isFeasible != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: GlassRadius.roundedPill,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    infeasible ? 'Cần điều chỉnh' : 'Khả thi',
                    style: GlassTypography.bodySm(
                      color: color,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (checked) ...[
            if (f == null)
              Text(
                'Đã đủ tiền, không cần góp thêm.',
                style: GlassTypography.bodyMd(color: GlassColors.success),
              )
            else ...[
              Text(
                'Cần ~${f.formattedRequiredPerMonth}/tháng'
                '${infeasible ? ' — vượt khả năng tài chính hiện tại' : ''}',
                style: GlassTypography.bodyMd(
                  color: color,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (f.availablePerMonthCents != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Có thể dành ~${formatVnd(f.availablePerMonthCents!)}/tháng',
                    style: GlassTypography.bodyMd(),
                  ),
                ),
              if (infeasible && f.suggestedDeadline != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Gợi ý dời hạn đến ${DateFormat('dd/MM/yyyy').format(f.suggestedDeadline!)}',
                    style: GlassTypography.bodyMd(),
                  ),
                ),
              if (infeasible && f.suggestedTargetCents != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Hoặc giảm mục tiêu còn ${formatVnd(f.suggestedTargetCents!)}',
                    style: GlassTypography.bodyMd(),
                  ),
                ),
            ],
            const SizedBox(height: 12),
          ],
          GlassGhostButton(
            label: checking ? 'Đang tính…' : 'Xem trước tính khả thi',
            onPressed: checking ? null : onCheck,
          ),
        ],
      ),
    );
  }
}
