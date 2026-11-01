import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_providers.dart';
import 'package:finmate/features/finance_methods/presentation/widgets/finance_widgets.dart';

String _vnd(int amount) => formatVnd(BigInt.from(amount));

/// Phần quản lý tài chính ở trang chủ. Chưa dùng cách nào thì mời bắt đầu; đã dùng thì cách chính hiện đủ các khối admin cấu hình
/// (`homeLayout`), cách bổ trợ gập lại bên dưới. Hai cách khác nhau vẽ ra hai trang chủ khác nhau mà app không cần biết tên cách nào.
class FinanceHomeSection extends ConsumerWidget {
  const FinanceHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(myMethodsProvider);
    return methods.when(
      loading: () => const FinanceCard(child: LinearProgressIndicator(minHeight: 4)),
      error: (error, _) => FinanceCard(
        child: Row(
          children: [
            Expanded(child: Text(errorMessage(error), style: AppTypography.caption(context).copyWith(color: AppColors.danger))),
            TextButton(onPressed: () => ref.invalidate(myMethodsProvider), child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) return const _ChooseMethodCard();
        final primary = list.firstWhere((m) => m.isPrimary, orElse: () => list.first);
        final others = list.where((m) => m.id != primary.id);
        return Column(
          children: [
            MethodHomeSection(userMethod: primary),
            for (final other in others) ...[
              const SizedBox(height: AppSpacing.md),
              MethodHomeSection(userMethod: other, collapsed: true),
            ],
          ],
        );
      },
    );
  }
}

/// Chưa dùng cách quản lý nào: mời làm khảo sát (hoặc xem gợi ý nếu đã làm khảo sát rồi).
class _ChooseMethodCard extends ConsumerWidget {
  const _ChooseMethodCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyDone = ref.watch(surveyProvider).valueOrNull?.isCompleted ?? false;
    return FinanceCard(
      key: const Key('choose_method_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.compass, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Chọn cách quản lý tài chính', style: AppTypography.h3(context))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            surveyDone
                ? 'Bạn đã trả lời khảo sát. Xem gợi ý cách quản lý hợp với bạn hoặc tự chọn từ danh sách.'
                : 'Trả lời vài câu hỏi để FinMate gợi ý cách quản lý hợp với bạn. Dùng hay không là quyền của bạn.',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ElevatedButton(
                key: const Key('start_finance_flow'),
                onPressed: () => context.push(surveyDone ? '/finance-recommendation' : '/finance-survey'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                ),
                child: Text(surveyDone ? 'Xem gợi ý' : 'Bắt đầu', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(onPressed: () => context.push('/finance-methods'), child: const Text('Tự chọn từ danh sách')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Trang chủ của MỘT cách quản lý: tiêu đề rồi các khối theo `homeLayout`. [collapsed] = gập lại (dùng cho cách bổ trợ).
class MethodHomeSection extends StatelessWidget {
  const MethodHomeSection({super.key, required this.userMethod, this.collapsed = false});

  final UserMethod userMethod;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final method = userMethod.method;
    final blocks = <Widget>[
      if (!method.available) _UnavailableNotice(key: Key('unavailable_notice_${method.code}'), name: method.name),
      for (final block in method.homeLayout)
        if (_buildBlock(block) case final widget?) widget,
    ];

    if (collapsed) {
      return FinanceCard(
        key: Key('method_home_${method.code}'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(method.name, style: AppTypography.bodyLarge(context)),
            subtitle: Text(roleLabel(userMethod.role), style: AppTypography.caption(context)),
            children: _spaced(blocks),
          ),
        ),
      );
    }

    return FinanceCard(
      key: Key('method_home_${method.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FinanceSectionLabel(roleLabel(userMethod.role)),
                    const SizedBox(height: 2),
                    Text(method.name, style: AppTypography.h3(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quản lý cách này',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => context.push('/finance-methods'),
                icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
              ),
            ],
          ),
          if (blocks.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), ..._spaced(blocks)],
        ],
      ),
    );
  }

  /// null = loại khối app chưa biết vẽ (backend mới hơn app): bỏ qua chứ không làm hỏng trang.
  Widget? _buildBlock(HomeBlock block) => switch (block.type) {
        HomeBlock.spendable => _SpendableBlock(key: Key('block_${block.type}'), block: block),
        HomeBlock.params => _ParamsBlock(userMethod: userMethod, block: block),
        HomeBlock.jars => _JarsBlock(key: Key('block_${block.type}'), userMethod: userMethod, block: block),
        HomeBlock.goals => _GoalsBlock(key: Key('block_${block.type}'), block: block),
        HomeBlock.starterSteps => _StarterStepsBlock(key: Key('block_${block.type}'), method: userMethod.method, block: block),
        _ => null,
      };

  static List<Widget> _spaced(List<Widget> blocks) => [
        for (var i = 0; i < blocks.length; i++) ...[if (i > 0) const SizedBox(height: AppSpacing.lg), blocks[i]],
      ];
}

/// Admin đã ngừng cung cấp cách này: người dùng vẫn dùng như cũ nhưng được báo và mời chọn cách khác (không tự gỡ, không mất dữ liệu).
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: AppSpacing.roundedSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.triangleAlert, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cách "$name" đã ngừng được cung cấp', style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Bạn vẫn dùng như cũ, nhưng nên chọn cách khác để tiếp tục được hỗ trợ.', style: AppTypography.caption(context)),
                TextButton(
                  key: const Key('choose_another_method'),
                  onPressed: () => context.push('/finance-recommendation'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  child: const Text('Xem gợi ý cách khác'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiền khả dụng của tháng: con số lớn "còn được chi" và ba số thành phần.
class _SpendableBlock extends ConsumerWidget {
  const _SpendableBlock({super.key, required this.block});

  final HomeBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendable = ref.watch(spendableProvider);
    return spendable.when(
      loading: () => const LinearProgressIndicator(minHeight: 4),
      error: (error, _) => Row(
        children: [
          Expanded(child: Text(errorMessage(error), style: AppTypography.caption(context).copyWith(color: AppColors.danger))),
          TextButton(onPressed: () => ref.invalidate(spendableProvider), child: const Text('Thử lại')),
        ],
      ),
      data: (info) {
        final amount = info.spendableWithoutUnaffordableCents;
        final unaffordable = info.unaffordableGoals;
        final reserved = info.goalSetAsideCents - unaffordable.fold<int>(0, (sum, g) => sum + g.setAsideCents);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FinanceSectionLabel(block.title ?? 'Còn được chi tháng này'),
            const SizedBox(height: AppSpacing.xs),
            if (amount == null)
              Text('Hãy nhập thu nhập hàng tháng để xem số tiền còn được chi.', style: AppTypography.body(context))
            else ...[
              for (final goal in unaffordable) _UnaffordableGoalNotice(goal: goal, incomeCents: info.incomeCents!),
              Text(
                _vnd(amount),
                key: const Key('spendable_amount'),
                style: AppTypography.moneyMedium.copyWith(color: amount < 0 ? AppColors.danger : Theme.of(context).colorScheme.onSurface),
              ),
              if (unaffordable.isNotEmpty)
                Text(
                  'Chưa tính ${unaffordable.map((g) => '"${g.name}"').join(', ')} vì mục tiêu chưa khả thi.',
                  key: const Key('spendable_excludes_goals'),
                  style: AppTypography.caption(context),
                ),
              const SizedBox(height: AppSpacing.sm),
              _StatRow(label: 'Thu nhập dự kiến', value: info.incomeCents == null ? '—' : _vnd(info.incomeCents!)),
              _StatRow(label: 'Đã chi', value: _vnd(info.spentCents)),
              if (reserved > 0) _StatRow(label: 'Dành cho mục tiêu', value: _vnd(reserved)),
            ],
          ],
        );
      },
    );
  }
}

/// Mục tiêu đòi dành mỗi tháng nhiều hơn cả thu nhập: nói thẳng vấn đề và chỉ đường sửa mục tiêu, thay vì để một số âm không giải thích.
class _UnaffordableGoalNotice extends StatelessWidget {
  const _UnaffordableGoalNotice({required this.goal, required this.incomeCents});

  final SpendableGoal goal;
  final int incomeCents;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('unaffordable_${goal.goalId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertCircle, size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Mục tiêu "${goal.name}" chưa khả thi', style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Để kịp hạn, bạn phải dành ${_vnd(goal.requiredPerMonthCents)} mỗi tháng, trong khi thu nhập chỉ ${_vnd(incomeCents)}. Hãy kéo dài hạn hoặc giảm số tiền của mục tiêu.',
            style: AppTypography.caption(context),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => context.push('/planning'), child: const Text('Sửa mục tiêu')),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.caption(context))),
          Text(value, style: AppTypography.tabular(AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// Tham số của cách đang dùng. `list`: nhãn và giá trị. `allocation`: chia phần trăm thu nhập thành các thanh kèm số tiền (nhãn và % luôn hiện, không chỉ dựa vào màu).
class _ParamsBlock extends ConsumerWidget {
  const _ParamsBlock({required this.userMethod, required this.block});

  final UserMethod userMethod;
  final HomeBlock block;

  List<ParamDef> _params() {
    final all = userMethod.method.params;
    final keys = block.keys;
    if (keys == null) return all;
    return [
      for (final key in keys)
        if (all.where((p) => p.key == key).firstOrNull case final param?) param,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = _params();
    if (params.isEmpty) return const SizedBox.shrink();
    final income = ref.watch(authControllerProvider).valueOrNull?.monthlyIncomeCents;

    return Column(
      key: Key('block_params_${block.title ?? block.keys?.join('_') ?? 'all'}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionLabel(block.title ?? 'Tham số'),
        const SizedBox(height: AppSpacing.sm),
        if (block.isAllocation) ..._allocation(context, params, income) else ..._list(context, params),
      ],
    );
  }

  List<Widget> _list(BuildContext context, List<ParamDef> params) => [
        for (final param in params)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(param.label, style: AppTypography.body(context))),
                Text(
                  param.format(userMethod.valueOf(param)),
                  style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ];

  List<Widget> _allocation(BuildContext context, List<ParamDef> params, int? income) {
    final percents = params.where((p) => p.isPercent).toList(growable: false);
    final total = percents.fold<int>(0, (sum, p) => sum + userMethod.valueOf(p));
    return [
      for (final param in percents) _AllocationRow(label: param.label, percent: userMethod.valueOf(param), income: income),
      const SizedBox(height: AppSpacing.xs),
      Text(
        income == null || income == 0 ? 'Tổng $total%. Nhập thu nhập hàng tháng để xem số tiền.' : 'Tổng $total% thu nhập.',
        style: AppTypography.caption(context).copyWith(color: total > 100 ? AppColors.danger : null),
      ),
    ];
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.label, required this.percent, required this.income});

  final String label;
  final int percent;
  final int? income;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = income == null || income == 0 ? null : income! * percent ~/ 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        label: '$label $percent%${amount == null ? '' : ', ${_vnd(amount)}'}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: AppTypography.body(context))),
                  Text('$percent%', style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700))),
                  if (amount != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(_vnd(amount), style: AppTypography.tabular(AppTypography.caption(context))),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: AppSpacing.roundedPill,
                color: AppColors.primary,
                backgroundColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Các hũ: mỗi hũ là phần thu nhập được chia, đã chi tháng này (theo danh mục thuộc hũ) và mức so với ngưỡng cảnh báo của người dùng.
/// Mức hiện bằng chữ kèm màu (không chỉ dựa vào màu); chưa khai thu nhập thì chỉ hiện số đã chi, không bịa số được chia.
class _JarsBlock extends ConsumerWidget {
  const _JarsBlock({super.key, required this.userMethod, required this.block});

  final UserMethod userMethod;
  final HomeBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jars = ref.watch(jarsProvider);
    return jars.when(
      loading: () => const LinearProgressIndicator(minHeight: 4),
      error: (error, _) => Row(
        children: [
          Expanded(child: Text(errorMessage(error), style: AppTypography.caption(context).copyWith(color: AppColors.danger))),
          TextButton(onPressed: () => ref.invalidate(jarsProvider), child: const Text('Thử lại')),
        ],
      ),
      data: (sets) {
        final set = sets.where((s) => s.userMethodId == userMethod.id).firstOrNull;
        if (set == null || set.jars.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FinanceSectionLabel(block.title ?? set.title ?? 'Các hũ tháng này'),
            const SizedBox(height: AppSpacing.sm),
            for (final jar in set.jars) _JarRow(jar: jar),
            if (set.unassignedSpentCents > 0)
              Text('Ngoài các hũ: ${_vnd(set.unassignedSpentCents)} (danh mục chưa thuộc hũ nào)', key: const Key('jars_unassigned'), style: AppTypography.caption(context)),
            if (set.incomeCents == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Nhập thu nhập hàng tháng để xem số tiền được chia cho từng hũ.', style: AppTypography.caption(context)),
              ),
          ],
        );
      },
    );
  }
}

class _JarRow extends StatelessWidget {
  const _JarRow({required this.jar});

  final Jar jar;

  Color get _color => switch (jar.level) {
        Jar.levelT1 => AppColors.warning,
        Jar.levelT2 || Jar.levelOver => AppColors.danger,
        _ => AppColors.safe,
      };

  String? get _status => switch (jar.level) {
        Jar.levelT1 => 'Gần chạm mức của hũ',
        Jar.levelT2 => 'Sắp cạn hũ',
        Jar.levelOver => 'Đã vượt hũ',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allocated = jar.allocatedCents;
    final remaining = jar.remainingCents;
    final used = jar.usedPct;
    final status = _status;
    return Padding(
      key: Key('jar_${jar.key}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        label: '${jar.label}, ${jar.allocationPct}% thu nhập, đã chi ${_vnd(jar.spentCents)}${allocated == null ? '' : ' trên ${_vnd(allocated)}'}${status == null ? '' : ', $status'}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(jar.label, style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700))),
                  Text('${jar.allocationPct}%', style: AppTypography.tabular(AppTypography.caption(context))),
                  if (used != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text('Đã dùng $used%', key: Key('jar_used_${jar.key}'), style: AppTypography.tabular(AppTypography.caption(context).copyWith(color: _color, fontWeight: FontWeight.w700))),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: used == null ? 0 : (used / 100).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: AppSpacing.roundedPill,
                color: _color,
                backgroundColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                allocated == null ? 'Đã chi ${_vnd(jar.spentCents)}' : 'Đã chi ${_vnd(jar.spentCents)} / ${_vnd(allocated)}',
                key: Key('jar_amount_${jar.key}'),
                style: AppTypography.tabular(AppTypography.caption(context)),
              ),
              if (remaining != null)
                Text(
                  remaining >= 0 ? 'Còn ${_vnd(remaining)}' : 'Vượt ${_vnd(-remaining)}',
                  style: AppTypography.tabular(AppTypography.caption(context).copyWith(color: remaining < 0 ? AppColors.danger : null)),
                ),
              if (status != null) Text(status, key: Key('jar_status_${jar.key}'), style: AppTypography.caption(context).copyWith(color: _color, fontWeight: FontWeight.w700)),
              if (jar.categories.isNotEmpty) Text('Gồm: ${jar.categories.map((c) => c.name).join(', ')}', style: AppTypography.caption(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mục tiêu đang dành tiền trong tháng; chưa có thì gợi ý mẫu mục tiêu; chưa có gì thì chỉ đường tới Kế hoạch.
class _GoalsBlock extends ConsumerWidget {
  const _GoalsBlock({super.key, required this.block});

  final HomeBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendable = ref.watch(spendableProvider).valueOrNull;
    final goals = spendable?.goals ?? const <SpendableGoal>[];
    final unaffordableIds = {for (final g in spendable?.unaffordableGoals ?? const <SpendableGoal>[]) g.goalId};
    final suggestions = ref.watch(goalSuggestionsProvider).valueOrNull ?? const <GoalSuggestion>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionLabel(block.title ?? 'Mục tiêu'),
        const SizedBox(height: AppSpacing.sm),
        if (goals.isNotEmpty)
          for (final goal in goals) _GoalRow(goal: goal, unaffordable: unaffordableIds.contains(goal.goalId))
        else if (suggestions.isNotEmpty)
          for (final suggestion in suggestions.take(2))
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: AppSpacing.sm,
              leading: const Icon(LucideIcons.target, size: 20, color: AppColors.primary),
              title: Text(suggestion.name, style: AppTypography.bodyMedium(context)),
              subtitle: Text(suggestion.description, style: AppTypography.caption(context)),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => context.push('/planning'),
            )
        else
          Row(
            children: [
              Expanded(child: Text('Chưa có mục tiêu nào. Tạo mục tiêu ở mục Kế hoạch.', style: AppTypography.caption(context))),
              TextButton(onPressed: () => context.push('/planning'), child: const Text('Kế hoạch')),
            ],
          ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, this.unaffordable = false});

  final SpendableGoal goal;
  final bool unaffordable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final required = goal.requiredPerMonthCents;
    final ratio = required <= 0 ? 0.0 : (goal.depositedThisMonthCents / required).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.name, style: AppTypography.bodyMedium(context)),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            borderRadius: AppSpacing.roundedPill,
            color: AppColors.safe,
            backgroundColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            unaffordable
                ? 'Cần ${_vnd(required)} mỗi tháng, vượt thu nhập của bạn'
                : required <= 0
                    ? 'Đã dành ${_vnd(goal.depositedThisMonthCents)} tháng này'
                    : 'Đã dành ${_vnd(goal.depositedThisMonthCents)} / ${_vnd(required)} tháng này',
            style: AppTypography.tabular(AppTypography.caption(context)),
          ),
        ],
      ),
    );
  }
}

/// Các bước bắt đầu của cách quản lý (cố định theo cách, không lưu tiến độ).
class _StarterStepsBlock extends StatelessWidget {
  const _StarterStepsBlock({super.key, required this.method, required this.block});

  final FinanceMethod method;
  final HomeBlock block;

  @override
  Widget build(BuildContext context) {
    if (method.starterSteps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionLabel(block.title ?? 'Bắt đầu như thế nào'),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < method.starterSteps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Text('${i + 1}', style: AppTypography.caption(context).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(method.starterSteps[i], style: AppTypography.body(context))),
              ],
            ),
          ),
      ],
    );
  }
}
