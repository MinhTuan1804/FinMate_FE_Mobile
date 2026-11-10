import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';

/// Giao dịch chia sẻ, báo cáo tháng, danh mục riêng của nhóm.
/// Đơn giản để test nhanh các API GroupFinanceController (phần giao dịch/báo cáo/danh mục) còn thiếu ở FE.
class GroupFinanceScreen extends ConsumerWidget {
  final String groupId;
  const GroupFinanceScreen({super.key, required this.groupId});

  Future<void> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(groupTransactionsProvider(groupId));
    ref.invalidate(groupMonthlyReportProvider(groupId));
    ref.invalidate(groupCategoriesProvider(groupId));
    ref.invalidate(groupShareRulesProvider(groupId));
    ref.invalidate(groupBudgetsProvider(groupId));
    ref.invalidate(groupGoalsProvider(groupId));
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm danh mục nhóm'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tên danh mục')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Thêm')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).createCategory(groupId: groupId, name: name);
      ref.invalidate(groupCategoriesProvider(groupId));
    }, 'Đã thêm danh mục');
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, GroupCategoryEntity category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text('Xóa danh mục "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).deleteCategory(groupId: groupId, categoryId: category.id);
      ref.invalidate(groupCategoriesProvider(groupId));
    }, 'Đã xóa danh mục');
  }

  Future<void> _addShareRule(BuildContext context, WidgetRef ref, List<FinancialAccount> accounts, List<Category> categories) async {
    final result = await showDialog<_ShareRuleInput>(
      context: context,
      builder: (_) => _ShareRuleDialog(accounts: accounts, categories: categories),
    );
    if (result == null || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).createShareRule(
            groupId: groupId,
            financialAccountId: result.financialAccountId,
            categoryId: result.categoryId,
          );
      ref.invalidate(groupShareRulesProvider(groupId));
    }, 'Đã tạo quy tắc tự chia sẻ');
  }

  Future<void> _deleteShareRule(BuildContext context, WidgetRef ref, GroupShareRuleEntity rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa quy tắc'),
        content: const Text('Xóa quy tắc tự chia sẻ này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).deleteShareRule(groupId: groupId, ruleId: rule.id);
      ref.invalidate(groupShareRulesProvider(groupId));
    }, 'Đã xóa quy tắc');
  }

  Future<void> _addBudget(BuildContext context, WidgetRef ref, List<Category> categories, List<GroupCategoryEntity> groupCategories) async {
    final result = await showDialog<_BudgetInput>(
      context: context,
      builder: (_) => _BudgetDialog(categories: categories, groupCategories: groupCategories),
    );
    if (result == null || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).createBudget(
            groupId: groupId,
            categoryId: result.categoryId,
            groupCategoryId: result.groupCategoryId,
            limitCents: result.limitCents,
          );
      ref.invalidate(groupBudgetsProvider(groupId));
    }, 'Đã tạo ngân sách');
  }

  Future<void> _editBudgetLimit(BuildContext context, WidgetRef ref, GroupBudgetEntity budget) async {
    final controller = TextEditingController(text: budget.limitCents.toString());
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi hạn mức ngân sách'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hạn mức (₫)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (text == null || !context.mounted) return;
    final limit = parseAmountInput(text);
    if (limit == null) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateBudgetLimit(groupId: groupId, budgetId: budget.id, limitCents: limit);
      ref.invalidate(groupBudgetsProvider(groupId));
    }, 'Đã đổi hạn mức');
  }

  Future<void> _deleteBudget(BuildContext context, WidgetRef ref, GroupBudgetEntity budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ngân sách'),
        content: const Text('Xóa ngân sách này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).deleteBudget(groupId: groupId, budgetId: budget.id);
      ref.invalidate(groupBudgetsProvider(groupId));
    }, 'Đã xóa ngân sách');
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_GroupGoalInput>(
      context: context,
      builder: (_) => const _GroupGoalDialog(),
    );
    if (result == null || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).createGoal(
            groupId: groupId,
            name: result.name,
            targetCents: result.targetCents,
            deadline: result.deadline,
          );
      ref.invalidate(groupGoalsProvider(groupId));
    }, 'Đã tạo mục tiêu');
  }

  Future<void> _contributeToGoal(BuildContext context, WidgetRef ref, SavingsGoalEntity goal) async {
    final result = await showDialog<_ContributeInput>(
      context: context,
      builder: (_) => const _ContributeDialog(),
    );
    if (result == null || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).contributeToGoal(
            groupId: groupId,
            goalId: goal.id,
            amountCents: result.amountCents,
            note: result.note,
          );
      ref.invalidate(groupGoalsProvider(groupId));
      ref.invalidate(groupGoalContributionsProvider((groupId, goal.id)));
    }, 'Đã góp tiền vào mục tiêu');
  }

  Future<void> _cancelGoal(BuildContext context, WidgetRef ref, SavingsGoalEntity goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy mục tiêu'),
        content: Text('Hủy mục tiêu "${goal.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hủy mục tiêu', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).cancelGoal(groupId: groupId, goalId: goal.id);
      ref.invalidate(groupGoalsProvider(groupId));
    }, 'Đã hủy mục tiêu');
  }

  Future<void> _showGoalContributions(BuildContext context, WidgetRef ref, SavingsGoalEntity goal) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Lịch sử góp tiền · ${goal.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer(
            builder: (context, ref, _) {
              final contributionsAsync = ref.watch(groupGoalContributionsProvider((groupId, goal.id)));
              return contributionsAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                error: (e, __) => Text(errorMessage(e)),
                data: (contributions) {
                  if (contributions.isEmpty) {
                    return const Text('Chưa có lần góp tiền nào.');
                  }
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: contributions
                          .map((c) => ListTile(
                                key: ValueKey('contribution-${c.id}'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${c.memberName} · ${c.formattedAmount}'),
                                subtitle: Text(
                                  '${DateFormat('dd/MM/yyyy').format(c.contributedAt)}${c.note != null ? " · ${c.note}" : ""}',
                                ),
                              ))
                          .toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }

  Future<void> _reclassify(
    BuildContext context,
    WidgetRef ref,
    GroupTransactionEntity tx,
    List<GroupCategoryEntity> categories,
  ) async {
    final picked = await showDialog<_ReclassifyChoice>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Phân loại lại giao dịch'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const _ReclassifyChoice(null)),
            child: Row(children: [
              if (tx.groupCategoryId == null) const Icon(LucideIcons.check, size: 16) else const SizedBox(width: 16),
              const SizedBox(width: 8),
              const Text('Không danh mục'),
            ]),
          ),
          ...categories.map((c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, _ReclassifyChoice(c.id)),
                child: Row(children: [
                  if (tx.groupCategoryId == c.id) const Icon(LucideIcons.check, size: 16) else const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(c.name),
                ]),
              )),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).reclassifyTransaction(
            groupId: groupId,
            transactionId: tx.id,
            groupCategoryId: picked.groupCategoryId,
          );
      ref.invalidate(groupTransactionsProvider(groupId));
      ref.invalidate(groupMonthlyReportProvider(groupId));
    }, 'Đã đổi danh mục');
  }

  Future<void> _removeTransaction(BuildContext context, WidgetRef ref, GroupTransactionEntity tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ chia sẻ giao dịch'),
        content: Text('Bỏ chia sẻ giao dịch "${tx.description ?? tx.categoryName}" khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Bỏ chia sẻ', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).removeTransaction(groupId: groupId, transactionId: tx.id);
      ref.invalidate(groupTransactionsProvider(groupId));
      ref.invalidate(groupMonthlyReportProvider(groupId));
    }, 'Đã bỏ chia sẻ giao dịch');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(groupMonthlyReportProvider(groupId));
    final transactionsAsync = ref.watch(groupTransactionsProvider(groupId));
    final categoriesAsync = ref.watch(groupCategoriesProvider(groupId));
    final categories = categoriesAsync.valueOrNull ?? const [];
    final shareRulesAsync = ref.watch(groupShareRulesProvider(groupId));
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final myCategories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final budgetsAsync = ref.watch(groupBudgetsProvider(groupId));
    final goalsAsync = ref.watch(groupGoalsProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tài chính nhóm')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Báo cáo tháng', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            reportAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
              data: (report) => _ReportCard(report: report),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Danh mục nhóm', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const ValueKey('add-category'),
                  tooltip: 'Thêm danh mục',
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _addCategory(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 4),
            categoriesAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
              data: (cats) {
                if (cats.isEmpty) {
                  return Text('Chưa có danh mục riêng nào.', style: AppTypography.caption(context));
                }
                return Column(
                  children: cats
                      .map((c) => ListTile(
                            key: ValueKey('category-${c.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(LucideIcons.tag, size: 18),
                            title: Text(c.name),
                            trailing: IconButton(
                              key: ValueKey('delete-category-${c.id}'),
                              icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                              onPressed: () => _deleteCategory(context, ref, c),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Quy tắc tự chia sẻ', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const ValueKey('add-share-rule'),
                  tooltip: 'Thêm quy tắc',
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _addShareRule(context, ref, accounts, myCategories),
                ),
              ],
            ),
            const SizedBox(height: 4),
            shareRulesAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
              data: (rules) {
                if (rules.isEmpty) {
                  return Text('Chưa có quy tắc tự chia sẻ nào.', style: AppTypography.caption(context));
                }
                return Column(
                  children: rules
                      .map((r) {
                        final accountName = r.financialAccountId == null
                            ? null
                            : accounts.where((a) => a.id == r.financialAccountId).firstOrNull?.name;
                        final categoryName =
                            r.categoryId == null ? null : myCategories.where((c) => c.id == r.categoryId).firstOrNull?.name;
                        final label = accountName != null
                            ? 'Tài khoản: $accountName'
                            : categoryName != null
                                ? 'Danh mục: $categoryName'
                                : 'Không rõ';
                        return ListTile(
                          key: ValueKey('share-rule-${r.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.repeat, size: 18),
                          title: Text(label),
                          trailing: IconButton(
                            key: ValueKey('delete-share-rule-${r.id}'),
                            icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                            onPressed: () => _deleteShareRule(context, ref, r),
                          ),
                        );
                      })
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Ngân sách nhóm', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const ValueKey('add-budget'),
                  tooltip: 'Thêm ngân sách',
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _addBudget(context, ref, myCategories, categories),
                ),
              ],
            ),
            const SizedBox(height: 4),
            budgetsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return Text('Chưa có ngân sách nào.', style: AppTypography.caption(context));
                }
                return Column(
                  children: budgets
                      .map((b) => ListTile(
                            key: ValueKey('budget-${b.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              LucideIcons.wallet,
                              size: 18,
                              color: b.statusLevel == GroupBudgetStatusLevel.danger
                                  ? AppColors.danger
                                  : b.statusLevel == GroupBudgetStatusLevel.warning
                                      ? AppColors.warning
                                      : AppColors.safe,
                            ),
                            title: Text(b.isTotal ? 'Ngân sách tổng' : (b.categoryName ?? 'Danh mục')),
                            subtitle: Text('${b.formattedSpent} / ${b.formattedLimit} (${b.percentUsed}%)'),
                            onTap: () => _editBudgetLimit(context, ref, b),
                            trailing: IconButton(
                              key: ValueKey('delete-budget-${b.id}'),
                              icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                              onPressed: () => _deleteBudget(context, ref, b),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Giao dịch đã chia sẻ', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            transactionsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
              data: (txs) {
                if (txs.isEmpty) {
                  return Text('Chưa có giao dịch nào được chia sẻ.', style: AppTypography.caption(context));
                }
                return Column(
                  children: txs
                      .map((tx) => ListTile(
                            key: ValueKey('transaction-${tx.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(LucideIcons.receipt, size: 18),
                            title: Text('${tx.memberName} · ${tx.formattedAmount}'),
                            subtitle: Text(
                              '${tx.categoryName} · ${DateFormat('dd/MM/yyyy').format(tx.transactedAt)}'
                              '${tx.merchantName != null ? " · ${tx.merchantName}" : ""}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: ValueKey('reclassify-${tx.id}'),
                                  tooltip: 'Đổi danh mục',
                                  icon: const Icon(LucideIcons.pencil, size: 18),
                                  onPressed: () => _reclassify(context, ref, tx, categories),
                                ),
                                IconButton(
                                  key: ValueKey('remove-transaction-${tx.id}'),
                                  tooltip: 'Bỏ chia sẻ',
                                  icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                                  onPressed: () => _removeTransaction(context, ref, tx),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Mục tiêu nhóm', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const ValueKey('add-goal'),
                  tooltip: 'Thêm mục tiêu',
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _addGoal(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 4),
            goalsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
              data: (goals) {
                if (goals.isEmpty) {
                  return Text('Chưa có mục tiêu nào.', style: AppTypography.caption(context));
                }
                return Column(
                  children: goals
                      .map((g) => ListTile(
                            key: ValueKey('goal-${g.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(LucideIcons.target, size: 18),
                            title: Text(g.title),
                            subtitle: Text(
                              '${g.formattedCurrent} / ${g.formattedTarget} (${g.progressPercentage.toStringAsFixed(0)}%) · ${g.status}',
                            ),
                            onTap: () => _showGoalContributions(context, ref, g),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: ValueKey('contribute-goal-${g.id}'),
                                  tooltip: 'Góp tiền',
                                  icon: const Icon(LucideIcons.plusCircle, size: 18),
                                  onPressed: () => _contributeToGoal(context, ref, g),
                                ),
                                IconButton(
                                  key: ValueKey('cancel-goal-${g.id}'),
                                  tooltip: 'Hủy mục tiêu',
                                  icon: Icon(LucideIcons.x, size: 18, color: AppColors.danger),
                                  onPressed: () => _cancelGoal(context, ref, g),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReclassifyChoice {
  final String? groupCategoryId;
  const _ReclassifyChoice(this.groupCategoryId);
}

class _ReportCard extends StatelessWidget {
  final GroupMonthlyReportEntity report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMedium,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tháng ${report.month}/${report.year}', style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text('Tổng chi: ${report.formattedTotalSpent}', key: const ValueKey('report-total-spent')),
          Text('Tổng thu: ${report.formattedTotalIncome}', key: const ValueKey('report-total-income')),
          if (report.byCategory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Theo danh mục', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
            ...report.byCategory.map((c) => Text('${c.categoryName}: ${c.formattedSpent}')),
          ],
          if (report.byMember.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Theo thành viên', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
            ...report.byMember.map((m) => Text('${m.memberName}: chi ${m.formattedSpent} · thu ${m.formattedIncome}')),
          ],
        ],
      ),
    );
  }
}

enum _ShareRuleTarget { account, category }

class _ShareRuleInput {
  final String? financialAccountId;
  final String? categoryId;
  const _ShareRuleInput({this.financialAccountId, this.categoryId});
}

/// Chỉ chọn đúng một trong hai: theo tài khoản của chính mình hoặc theo danh mục của chính mình.
class _ShareRuleDialog extends StatefulWidget {
  final List<FinancialAccount> accounts;
  final List<Category> categories;
  const _ShareRuleDialog({required this.accounts, required this.categories});

  @override
  State<_ShareRuleDialog> createState() => _ShareRuleDialogState();
}

class _ShareRuleDialogState extends State<_ShareRuleDialog> {
  _ShareRuleTarget _target = _ShareRuleTarget.account;
  String? _accountId;
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final selectedId = _target == _ShareRuleTarget.account ? _accountId : _categoryId;
    return AlertDialog(
      title: const Text('Thêm quy tắc tự chia sẻ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_ShareRuleTarget>(
            segments: const [
              ButtonSegment(value: _ShareRuleTarget.account, label: Text('Theo tài khoản')),
              ButtonSegment(value: _ShareRuleTarget.category, label: Text('Theo danh mục')),
            ],
            selected: {_target},
            onSelectionChanged: (s) => setState(() => _target = s.first),
          ),
          const SizedBox(height: 12),
          if (_target == _ShareRuleTarget.account)
            DropdownButtonFormField<String>(
              key: const ValueKey('share-rule-account'),
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Tài khoản'),
              items: widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => _accountId = v),
            )
          else
            DropdownButtonFormField<String>(
              key: const ValueKey('share-rule-category'),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          key: const ValueKey('create-share-rule'),
          onPressed: selectedId == null
              ? null
              : () => Navigator.pop(
                    context,
                    _target == _ShareRuleTarget.account
                        ? _ShareRuleInput(financialAccountId: _accountId)
                        : _ShareRuleInput(categoryId: _categoryId),
                  ),
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

enum _BudgetTarget { total, category, groupCategory }

class _BudgetInput {
  final String? categoryId;
  final String? groupCategoryId;
  final BigInt limitCents;
  const _BudgetInput({this.categoryId, this.groupCategoryId, required this.limitCents});
}

/// [categories] là danh mục hệ thống của chính mình; [groupCategories] là danh mục riêng của nhóm.
/// Chọn "Tổng nhóm" thì cả hai id đều null.
class _BudgetDialog extends StatefulWidget {
  final List<Category> categories;
  final List<GroupCategoryEntity> groupCategories;
  const _BudgetDialog({required this.categories, required this.groupCategories});

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  _BudgetTarget _target = _BudgetTarget.total;
  String? _categoryId;
  String? _groupCategoryId;
  final _limit = TextEditingController();

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetValid = switch (_target) {
      _BudgetTarget.total => true,
      _BudgetTarget.category => _categoryId != null,
      _BudgetTarget.groupCategory => _groupCategoryId != null,
    };
    return AlertDialog(
      title: const Text('Thêm ngân sách'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<_BudgetTarget>(
              segments: const [
                ButtonSegment(value: _BudgetTarget.total, label: Text('Tổng nhóm')),
                ButtonSegment(value: _BudgetTarget.category, label: Text('Danh mục hệ thống')),
                ButtonSegment(value: _BudgetTarget.groupCategory, label: Text('Danh mục nhóm')),
              ],
              selected: {_target},
              onSelectionChanged: (s) => setState(() => _target = s.first),
            ),
            const SizedBox(height: 12),
            if (_target == _BudgetTarget.category)
              DropdownButtonFormField<String>(
                key: const ValueKey('budget-category'),
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Danh mục hệ thống'),
                items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            if (_target == _BudgetTarget.groupCategory)
              DropdownButtonFormField<String>(
                key: const ValueKey('budget-group-category'),
                initialValue: _groupCategoryId,
                decoration: const InputDecoration(labelText: 'Danh mục nhóm'),
                items: widget.groupCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _groupCategoryId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('budget-limit'),
              controller: _limit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hạn mức (₫)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          key: const ValueKey('create-budget'),
          onPressed: !targetValid
              ? null
              : () {
                  final limit = parseAmountInput(_limit.text);
                  if (limit == null) return;
                  Navigator.pop(
                    context,
                    _BudgetInput(
                      categoryId: _target == _BudgetTarget.category ? _categoryId : null,
                      groupCategoryId: _target == _BudgetTarget.groupCategory ? _groupCategoryId : null,
                      limitCents: limit,
                    ),
                  );
                },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

class _GroupGoalInput {
  final String name;
  final BigInt targetCents;
  final DateTime? deadline;
  const _GroupGoalInput({required this.name, required this.targetCents, this.deadline});
}

class _GroupGoalDialog extends StatefulWidget {
  const _GroupGoalDialog();

  @override
  State<_GroupGoalDialog> createState() => _GroupGoalDialogState();
}

class _GroupGoalDialogState extends State<_GroupGoalDialog> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  DateTime? _deadline;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm mục tiêu nhóm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên mục tiêu')),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tiền mục tiêu (₫)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('goal-deadline'),
            onPressed: _pickDeadline,
            icon: const Icon(LucideIcons.calendar, size: 16),
            label: Text(_deadline == null ? 'Chọn hạn chót (tùy chọn)' : DateFormat('dd/MM/yyyy').format(_deadline!)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          key: const ValueKey('create-goal'),
          onPressed: () {
            final name = _name.text.trim();
            final target = parseAmountInput(_target.text);
            if (name.isEmpty || target == null) return;
            Navigator.pop(context, _GroupGoalInput(name: name, targetCents: target, deadline: _deadline));
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

class _ContributeInput {
  final BigInt amountCents;
  final String? note;
  const _ContributeInput({required this.amountCents, this.note});
}

class _ContributeDialog extends StatefulWidget {
  const _ContributeDialog();

  @override
  State<_ContributeDialog> createState() => _ContributeDialogState();
}

class _ContributeDialogState extends State<_ContributeDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Góp tiền vào mục tiêu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tiền (₫)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          key: const ValueKey('submit-contribute'),
          onPressed: () {
            final amount = parseAmountInput(_amount.text);
            if (amount == null) return;
            Navigator.pop(
              context,
              _ContributeInput(amountCents: amount, note: _note.text.trim().isEmpty ? null : _note.text.trim()),
            );
          },
          child: const Text('Góp'),
        ),
      ],
    );
  }
}
