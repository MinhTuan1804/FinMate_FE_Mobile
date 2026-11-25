import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/jar_detail_controller.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_loading_spinner.dart';
import 'package:finmate/shared/widgets/glass/glass_circular_progress.dart';
import 'package:finmate/shared/widgets/glass/glass_transaction_row.dart';

/// B6 — Chi tiết một hũ: ngân sách tháng này, danh mục liên kết (so với ngân sách đã khai ở
/// Kế hoạch), giao dịch gần đây của các danh mục đó.
class JarDetailScreen extends ConsumerWidget {
  final String userMethodId;
  final String jarKey;

  const JarDetailScreen({super.key, required this.userMethodId, required this.jarKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = JarKey(userMethodId: userMethodId, jarKey: jarKey);
    final jarsAsync = ref.watch(jarsProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(
          context,
          title: jarsAsync.maybeWhen(
            data: (sets) {
              final jar = _findJar(sets, key);
              return jar == null ? 'Chi tiết hũ' : 'Chi tiết ${jar.label}';
            },
            orElse: () => 'Chi tiết hũ',
          ),
        ),
        body: SafeArea(
          child: jarsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text(errorMessage(e), style: GlassTypography.bodyMd())),
            data: (sets) {
              JarSetEntity? jarSet;
              for (final s in sets) {
                if (s.userMethodId == userMethodId) {
                  jarSet = s;
                  break;
                }
              }
              final jar = _findJar(sets, key);
              if (jar == null || jarSet == null) {
                return Center(child: Text('Không tìm thấy hũ này.', style: GlassTypography.bodyMd()));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(jarSet.title ?? jarSet.methodName, style: GlassTypography.bodySm(), overflow: TextOverflow.ellipsis)),
                      Icon(LucideIcons.chevronRight, size: 14, color: GlassColors.textMuted),
                      Flexible(child: Text(jar.label, style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      GlassBadge(text: '${jar.allocationPct}% THU NHẬP'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHero(jar),
                  const SizedBox(height: 20),
                  _CategoryBudgetsSection(jarKeyValue: key, jarLabel: jar.label),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Giao dịch gần đây', style: GlassTypography.headlineSm()),
                      Text('Tháng ${DateTime.now().month}', style: GlassTypography.bodySm()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _RecentTransactionsSection(jarKeyValue: key),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  JarEntity? _findJar(List<JarSetEntity> sets, JarKey key) {
    for (final s in sets) {
      if (s.userMethodId != key.userMethodId) continue;
      for (final j in s.jars) {
        if (j.key == key.jarKey) return j;
      }
    }
    return null;
  }

  Widget _buildHero(JarEntity jar) {
    final percent = jar.usedPct?.toDouble() ?? 0;
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = lastDayOfMonth - now.day + 1;
    final perDay = jar.remainingCents != null && daysRemaining > 0
        ? jar.remainingCents! ~/ BigInt.from(daysRemaining)
        : null;

    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(21),
      borderRadius: GlassRadius.roundedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NGÂN SÁCH THÁNG NÀY', style: GlassTypography.labelCaps(color: GlassColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: jar.allocatedCents == null ? 'Chưa biết' : formatVnd(jar.allocatedCents!),
                            style: GlassTypography.displayHero(),
                          ),
                          if (jar.allocatedCents != null)
                            TextSpan(text: ' / tháng', style: GlassTypography.bodyMd()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: GlassColors.fieldFill, shape: BoxShape.circle),
                child: Icon(LucideIcons.wallet, size: 18, color: GlassColors.slateAnchor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: GlassColors.glassBorder),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đã chi tiêu', style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
                    Text(formatVnd(jar.spentCents), style: GlassTypography.labelNumeric().copyWith(fontSize: 18, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', FontWeight.w700.value.toDouble())])),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: GlassColors.fieldFill,
                        borderRadius: GlassRadius.roundedPill,
                        border: Border.all(color: GlassColors.fieldBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendar, size: 13, color: GlassColors.slateAnchor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              jar.remainingCents == null
                                  ? 'Chưa biết còn lại'
                                  : 'Còn ${formatVnd(jar.remainingCents!)} • $daysRemaining ngày tới',
                              style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GlassCircularProgress(
                size: 96,
                percent: percent,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${percent.round()}%', style: GlassTypography.headlineSm()),
                    Text('định mức', style: GlassTypography.bodySm()),
                  ],
                ),
              ),
            ],
          ),
          if (perDay != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: GlassColors.fieldFill, borderRadius: GlassRadius.roundedPill),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: GlassColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tiến độ chi tiêu an toàn', style: GlassTypography.bodySm(), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text('~${formatVnd(perDay)} / ngày', style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBudgetsSection extends ConsumerWidget {
  final JarKey jarKeyValue;
  final String jarLabel;

  const _CategoryBudgetsSection({required this.jarKeyValue, required this.jarLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jarCategoryBudgetsProvider(jarKeyValue));
    final categoriesAsync = ref.watch(categoriesProvider);
    final slugById = categoriesAsync.maybeWhen(
      data: (categories) => {for (final c in categories) c.id: c.slug},
      orElse: () => const <String, String>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Danh mục liên kết', style: GlassTypography.headlineSm()),
                  const SizedBox(height: 2),
                  async.maybeWhen(
                    data: (budgets) => Text('${budgets.length} hạn mức con thuộc hũ $jarLabel', style: GlassTypography.bodySm()),
                    orElse: () => Text('Thuộc hũ $jarLabel', style: GlassTypography.bodySm()),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        async.when(
          loading: () => const GlassLoadingSpinner(),
          error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
          data: (budgets) {
            if (budgets.isEmpty) {
              return GlassCard(child: Text('Chưa khai hạn mức cho danh mục trong hũ này.', style: GlassTypography.bodyMd()));
            }
            return Column(
              children: [
                for (final b in budgets) ...[
                  _CategoryBudgetRow(budget: b, slug: slugById[b.categoryId]),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  final BudgetEntity budget;
  final String? slug;

  const _CategoryBudgetRow({required this.budget, required this.slug});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: GlassColors.accentSkyBlue.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
            child: Icon(categoryIcon(slug), size: 18, color: GlassColors.slateAnchor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(budget.category, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Đã dùng: ${budget.formattedSpent}', style: GlassTypography.bodySm()),
                    const SizedBox(width: 6),
                    GlassBadge(text: '${budget.spendingPercentage.round()}%', color: budget.statusColor),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(budget.formattedLimit, style: GlassTypography.labelNumeric()),
              Text('Hạn mức', style: GlassTypography.bodySm()),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsSection extends ConsumerWidget {
  final JarKey jarKeyValue;

  const _RecentTransactionsSection({required this.jarKeyValue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jarTransactionsProvider(jarKeyValue));
    return async.when(
      loading: () => const GlassLoadingSpinner(),
      error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
      data: (list) {
        if (list.isEmpty) {
          return GlassCard(child: Text('Chưa có giao dịch nào trong hũ này.', style: GlassTypography.bodyMd()));
        }
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [for (final tx in list) _buildRow(tx)]),
        );
      },
    );
  }

  Widget _buildRow(TransactionEntity tx) {
    final isExpense = tx.type == TransactionType.expense;
    return GlassTransactionRow(
      icon: isExpense ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
      iconColor: isExpense ? GlassColors.danger : GlassColors.success,
      title: tx.description.isNotEmpty ? tx.description : (tx.categoryName ?? 'Giao dịch'),
      subtitle: tx.categoryName ?? 'Chung',
      amountText: '${isExpense ? '-' : '+'}${tx.formattedAmount}',
      isExpense: isExpense,
    );
  }
}
