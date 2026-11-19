import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/groups/data/group_funds_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/domain/group_fund.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';

enum _DetailTab { transactions, budgets, goals, fund }

/// I3 — Chi tiết nhóm (Stitch `i3_group_detail`). Hero card là quỹ chung thật (Phase 85), KHÔNG
/// phải banner "nợ"/cấn trừ (xem quyết định phạm vi Luồng 8a — hệ thống thật là 1 sổ quỹ chung, không
/// phải chia nợ từng khoản giữa thành viên). Tab "Chia tiền" của Stitch thay bằng tab "Quỹ chung"
/// (sổ quỹ thật, `GET /funds/{fundId}/entries`). Không build bottom nav 4 tab của mockup (app không
/// có nav shell dùng chung). Icon mời thành viên trên AppBar push I5; icon bánh răng push I7 (Cài
/// đặt nhóm — đổi tên/hiển thị giao dịch/cảnh báo/tạo quỹ/chuyển quyền/rời-giải tán nhóm); tiêu đề
/// "N thành viên" push I4.
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  _DetailTab _tab = _DetailTab.transactions;

  void _refreshDetail(WidgetRef ref) {
    ref.invalidate(groupDetailProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(groupActivitiesProvider(widget.groupId));
    ref.invalidate(groupInvitationsProvider(widget.groupId));
    ref.invalidate(groupPrimaryFundProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: groupAsync.maybeWhen(
            data: (g) => GestureDetector(
              key: const ValueKey('go-members'),
              onTap: () =>
                  context.push('/group-members', extra: widget.groupId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(g.name, style: GlassTypography.headlineSm()),
                  Text(
                    '${g.memberCount} thành viên',
                    style: GlassTypography.bodySm(),
                  ),
                ],
              ),
            ),
            orElse: () =>
                Text('Chi tiết nhóm', style: GlassTypography.headlineSm()),
          ),
          actions: [
            groupAsync.maybeWhen(
              data: (g) => g.isOwner
                  ? IconButton(
                      key: const ValueKey('invite-member'),
                      tooltip: 'Mời thành viên',
                      icon: Icon(
                        LucideIcons.userPlus,
                        color: GlassColors.textPrimary,
                      ),
                      onPressed: () =>
                          context.push('/group-invite', extra: widget.groupId),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
            groupAsync.maybeWhen(
              data: (g) => IconButton(
                key: const ValueKey('open-group-settings'),
                tooltip: 'Cài đặt nhóm',
                icon: Icon(
                  LucideIcons.settings,
                  color: GlassColors.textPrimary,
                ),
                onPressed: () =>
                    context.push('/group-settings', extra: widget.groupId),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: SafeArea(
          child: groupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(
              child: Text(
                errorMessage(e),
                style: GlassTypography.bodyMd(color: GlassColors.danger),
              ),
            ),
            data: (group) => RefreshIndicator(
              onRefresh: () async => _refreshDetail(ref),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _HeroFundCard(groupId: widget.groupId),
                  const SizedBox(height: 20),
                  _buildTabs(),
                  const SizedBox(height: 16),
                  switch (_tab) {
                    _DetailTab.transactions => _TransactionsTab(
                      groupId: widget.groupId,
                    ),
                    _DetailTab.budgets => _BudgetsTab(groupId: widget.groupId),
                    _DetailTab.goals => _GoalsTab(groupId: widget.groupId),
                    _DetailTab.fund => _FundTab(groupId: widget.groupId),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget chip(String label, _DetailTab tab) {
      final selected = _tab == tab;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          key: ValueKey('detail-tab-${tab.name}'),
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? GlassColors.ink : GlassColors.glassFill,
              borderRadius: GlassRadius.roundedPill,
              border: Border.all(
                color: selected ? GlassColors.ink : GlassColors.glassBorder,
              ),
            ),
            child: Text(
              label,
              style: GlassTypography.bodyMd(
                color: selected ? Colors.white : GlassColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Giao dịch', _DetailTab.transactions),
          chip('Ngân sách', _DetailTab.budgets),
          chip('Mục tiêu', _DetailTab.goals),
          chip('Quỹ chung', _DetailTab.fund),
        ],
      ),
    );
  }
}

class _HeroFundCard extends ConsumerWidget {
  final String groupId;
  const _HeroFundCard({required this.groupId});

  void _needFundFirst(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Nhóm chưa có quỹ chung — tạo quỹ trước trong Cài đặt nhóm.',
        ),
        action: SnackBarAction(
          label: 'Cài đặt nhóm',
          onPressed: () => context.push('/group-settings', extra: groupId),
        ),
      ),
    );
  }

  void _refreshFund(WidgetRef ref, String fundId) {
    ref.invalidate(groupFundsProvider(groupId));
    ref.invalidate(groupFundSummaryProvider((groupId, fundId)));
    ref.invalidate(groupFundEntriesProvider((groupId, fundId)));
  }

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    String fundId,
  ) async {
    final input = await showModalBottomSheet<_FundEntryInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ContributeFundSheet(),
    );
    if (input == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupFundsRepositoryProvider)
          .createEntry(
            groupId: groupId,
            fundId: fundId,
            kind: GroupFundEntryKind.contribution,
            amountCents: input.amountCents,
            note: input.note,
          );
      _refreshFund(ref, fundId);
      messenger.showSnackBar(const SnackBar(content: Text('Đã nạp quỹ nhóm')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: GlassColors.danger,
        ),
      );
    }
  }

  Future<void> _recordExpense(
    BuildContext context,
    WidgetRef ref,
    String fundId,
  ) async {
    final List<Category> categories;
    final List<GroupCategoryEntity> groupCategories;
    try {
      categories = await ref.read(categoriesProvider.future);
      groupCategories = await ref.read(groupCategoriesProvider(groupId).future);
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e)),
            backgroundColor: GlassColors.danger,
          ),
        );
      return;
    }
    if (!context.mounted) return;
    final input = await showModalBottomSheet<_FundEntryInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordExpenseSheet(
        categories: categories,
        groupCategories: groupCategories,
      ),
    );
    if (input == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupFundsRepositoryProvider)
          .createEntry(
            groupId: groupId,
            fundId: fundId,
            kind: GroupFundEntryKind.expense,
            amountCents: input.amountCents,
            categoryId: input.categoryId,
            groupCategoryId: input.groupCategoryId,
            merchantName: input.merchantName,
            note: input.note,
          );
      _refreshFund(ref, fundId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã ghi khoản chi từ quỹ')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: GlassColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundAsync = ref.watch(groupPrimaryFundProvider(groupId));
    final budgetsAsync = ref.watch(groupBudgetsProvider(groupId));
    final fundId = fundAsync.valueOrNull?.id;

    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUỸ CHUNG KHẢ DỤNG',
                style: GlassTypography.labelCaps(
                  color: GlassColors.accentSkyBlue,
                ),
              ),
              fundAsync.maybeWhen(
                data: (f) => f == null
                    ? const SizedBox.shrink()
                    : GlassBadge(
                        text: 'Đang hoạt động',
                        color: GlassColors.success,
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          fundAsync.when(
            loading: () => Text('…', style: GlassTypography.displayHero()),
            error: (_, __) => Text('—', style: GlassTypography.displayHero()),
            data: (fund) => fund == null
                ? Text(
                    'Nhóm chưa có quỹ chung nào.',
                    style: GlassTypography.bodyMd(),
                  )
                : Text(
                    fund.formattedBalance,
                    style: GlassTypography.displayHero(
                      color: fund.isNegative
                          ? GlassColors.danger
                          : GlassColors.textPrimary,
                    ),
                  ),
          ),
          budgetsAsync.maybeWhen(
            data: (budgets) {
              GroupBudgetEntity? total;
              for (final b in budgets) {
                if (b.isTotal) {
                  total = b;
                  break;
                }
              }
              if (total == null) return const SizedBox.shrink();
              final state = switch (total.statusLevel) {
                GroupBudgetStatusLevel.danger => GlassProgressState.danger,
                GroupBudgetStatusLevel.warning => GlassProgressState.warning,
                GroupBudgetStatusLevel.safe => GlassProgressState.success,
              };
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã chi tháng này: ${total.formattedSpent}',
                          style: GlassTypography.bodySm(),
                        ),
                        Text(
                          '${total.percentUsed}%',
                          style: GlassTypography.bodySm(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GlassProgressBar(
                      percent: total.percentUsed.toDouble(),
                      state: state,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hạn mức ${total.formattedLimit}',
                      style: GlassTypography.bodySm(),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('fund-contribute'),
                  onPressed: () => fundId == null
                      ? _needFundFirst(context)
                      : _contribute(context, ref, fundId),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                  icon: const Icon(LucideIcons.plusCircle, size: 16),
                  // Một dòng, tự thu nhỏ chữ khi hẹp thay vì xuống hàng.
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Nạp quỹ nhóm', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('fund-record-expense'),
                  onPressed: () => fundId == null
                      ? _needFundFirst(context)
                      : _recordExpense(context, ref, fundId),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                  icon: const Icon(LucideIcons.receipt, size: 16),
                  // Một dòng, tự thu nhỏ chữ khi hẹp thay vì xuống hàng.
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Ghi khoản chi', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FundEntryInput {
  final BigInt amountCents;
  final String? note;
  final String? categoryId;
  final String? groupCategoryId;
  final String? merchantName;
  const _FundEntryInput({
    required this.amountCents,
    this.note,
    this.categoryId,
    this.groupCategoryId,
    this.merchantName,
  });
}

/// Khung chung cho 2 sheet "Nạp quỹ nhóm"/"Ghi khoản chi" — cùng phong cách bottom sheet kính (glass)
/// dùng xuyên suốt I2-I3, không dùng AlertDialog kiểu code cũ ở `group_finance_screen.dart`.
class _FundEntrySheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FundEntrySheetScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        // GlassCard làm mờ nội dung phía sau; chỉ tô màu bán trong suốt thì chữ của màn dưới xuyên qua sheet.
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: GlassCard(
            level: 3,
            padding: const EdgeInsets.all(16),
            borderRadius: GlassRadius.roundedCardLarge,
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: GlassTypography.headlineSm()),
                    const SizedBox(height: 16),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContributeFundSheet extends StatefulWidget {
  const _ContributeFundSheet();

  @override
  State<_ContributeFundSheet> createState() => _ContributeFundSheetState();
}

class _ContributeFundSheetState extends State<_ContributeFundSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmountInput(_amount.text);
    if (amount == null) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      return;
    }
    Navigator.pop(
      context,
      _FundEntryInput(
        amountCents: amount,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FundEntrySheetScaffold(
      title: 'Nạp quỹ nhóm',
      children: [
        Text(
          'Số tiền',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('contribute-amount'),
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            hintText: '0',
            suffixText: '₫',
            errorText: _amountError,
          ),
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Ghi chú (không bắt buộc)',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('contribute-note'),
          controller: _note,
          decoration: const InputDecoration(hintText: 'Vd: góp quỹ tháng 11'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const ValueKey('submit-contribute'),
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: GlassRadius.roundedPill,
              ),
            ),
            child: Text('Nạp quỹ', style: GlassTypography.buttonText()),
          ),
        ),
      ],
    );
  }
}

/// [categories] là danh mục hệ thống của chính mình; [groupCategories] là danh mục riêng của nhóm.
/// BE bắt buộc đúng 1 trong 2 cho dòng `Expense` (xem `docs/group-api.md` phần "Dòng quỹ").
class _RecordExpenseSheet extends StatefulWidget {
  final List<Category> categories;
  final List<GroupCategoryEntity> groupCategories;
  const _RecordExpenseSheet({
    required this.categories,
    required this.groupCategories,
  });

  @override
  State<_RecordExpenseSheet> createState() => _RecordExpenseSheetState();
}

enum _ExpenseCategoryTarget { system, group }

class _RecordExpenseSheetState extends State<_RecordExpenseSheet> {
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  _ExpenseCategoryTarget _target = _ExpenseCategoryTarget.system;
  String? _categoryId;
  String? _groupCategoryId;
  String? _amountError;
  String? _categoryError;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmountInput(_amount.text);
    final categoryOk = _target == _ExpenseCategoryTarget.system
        ? _categoryId != null
        : _groupCategoryId != null;
    setState(() {
      _amountError = amount == null ? 'Nhập số tiền hợp lệ' : null;
      _categoryError = categoryOk ? null : 'Chọn danh mục';
    });
    if (amount == null || !categoryOk) return;
    Navigator.pop(
      context,
      _FundEntryInput(
        amountCents: amount,
        categoryId: _target == _ExpenseCategoryTarget.system
            ? _categoryId
            : null,
        groupCategoryId: _target == _ExpenseCategoryTarget.group
            ? _groupCategoryId
            : null,
        merchantName: _merchant.text.trim().isEmpty
            ? null
            : _merchant.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FundEntrySheetScaffold(
      title: 'Ghi khoản chi từ quỹ',
      children: [
        Text(
          'Số tiền',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('expense-amount'),
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            hintText: '0',
            suffixText: '₫',
            errorText: _amountError,
          ),
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Danh mục',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_ExpenseCategoryTarget>(
          key: const ValueKey('expense-category-target'),
          segments: const [
            ButtonSegment(
              value: _ExpenseCategoryTarget.system,
              label: Text('Hệ thống'),
            ),
            ButtonSegment(
              value: _ExpenseCategoryTarget.group,
              label: Text('Của nhóm'),
            ),
          ],
          selected: {_target},
          onSelectionChanged: (s) => setState(() {
            _target = s.first;
            _categoryError = null;
          }),
        ),
        const SizedBox(height: 8),
        if (_target == _ExpenseCategoryTarget.system)
          DropdownButtonFormField<String>(
            key: const ValueKey('expense-category-system'),
            initialValue: _categoryId,
            decoration: InputDecoration(
              hintText: 'Chọn danh mục hệ thống',
              errorText: _categoryError,
            ),
            items: widget.categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() {
              _categoryId = v;
              _categoryError = null;
            }),
          )
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('expense-category-group'),
            initialValue: _groupCategoryId,
            decoration: InputDecoration(
              hintText: 'Chọn danh mục của nhóm',
              errorText: _categoryError,
            ),
            items: widget.groupCategories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() {
              _groupCategoryId = v;
              _categoryError = null;
            }),
          ),
        const SizedBox(height: 12),
        Text(
          'Chi cho (không bắt buộc)',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('expense-merchant'),
          controller: _merchant,
          decoration: const InputDecoration(hintText: 'Vd: Siêu thị WinMart'),
        ),
        const SizedBox(height: 12),
        Text(
          'Ghi chú (không bắt buộc)',
          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('expense-note'),
          controller: _note,
          decoration: const InputDecoration(hintText: 'Ghi chú thêm'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const ValueKey('submit-expense'),
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: GlassRadius.roundedPill,
              ),
            ),
            child: Text('Ghi khoản chi', style: GlassTypography.buttonText()),
          ),
        ),
      ],
    );
  }
}

class _TransactionsTab extends ConsumerWidget {
  final String groupId;
  const _TransactionsTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(groupTransactionsProvider(groupId));
    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Text(
        errorMessage(e),
        style: GlassTypography.bodyMd(color: GlassColors.danger),
      ),
      data: (list) {
        if (list.isEmpty)
          return Text(
            'Chưa có giao dịch nào được chia sẻ vào nhóm.',
            style: GlassTypography.bodyMd(),
          );
        return Column(
          children: list
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.merchantName ??
                                    t.description ??
                                    t.categoryName,
                                style: GlassTypography.bodyMd(
                                  color: GlassColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${t.memberName} · ${DateFormat('dd/MM').format(t.transactedAt)}',
                                style: GlassTypography.bodySm(),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          t.formattedAmount,
                          style: GlassTypography.labelNumeric(
                            color: t.transactionType == TransactionType.income
                                ? GlassColors.success
                                : GlassColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BudgetsTab extends ConsumerWidget {
  final String groupId;
  const _BudgetsTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(groupBudgetsProvider(groupId));
    return budgetsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Text(
        errorMessage(e),
        style: GlassTypography.bodyMd(color: GlassColors.danger),
      ),
      data: (list) {
        if (list.isEmpty)
          return Text(
            'Nhóm chưa đặt ngân sách nào.',
            style: GlassTypography.bodyMd(),
          );
        return Column(
          children: list
              .map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              b.isTotal
                                  ? 'Ngân sách tổng'
                                  : (b.categoryName ?? 'Danh mục'),
                              style: GlassTypography.bodyMd(
                                color: GlassColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${b.percentUsed}%',
                              style: GlassTypography.bodySm(
                                color: b.isOverLimit
                                    ? GlassColors.danger
                                    : GlassColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GlassProgressBar(
                          percent: b.percentUsed.toDouble(),
                          state: b.statusLevel == GroupBudgetStatusLevel.danger
                              ? GlassProgressState.danger
                              : b.statusLevel == GroupBudgetStatusLevel.warning
                              ? GlassProgressState.warning
                              : GlassProgressState.success,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${b.formattedSpent} / ${b.formattedLimit}',
                          style: GlassTypography.bodySm(),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _GoalsTab extends ConsumerWidget {
  final String groupId;
  const _GoalsTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(groupGoalsProvider(groupId));
    return goalsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Text(
        errorMessage(e),
        style: GlassTypography.bodyMd(color: GlassColors.danger),
      ),
      data: (list) {
        if (list.isEmpty)
          return Text(
            'Nhóm chưa có mục tiêu nào.',
            style: GlassTypography.bodyMd(),
          );
        return Column(
          children: list
              .map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.title,
                          style: GlassTypography.bodyMd(
                            color: GlassColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassProgressBar(
                          percent: g.progressPercentage,
                          state: g.isCompleted
                              ? GlassProgressState.success
                              : GlassProgressState.normal,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${g.formattedCurrent} / ${g.formattedTarget}',
                          style: GlassTypography.bodySm(),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FundTab extends ConsumerWidget {
  final String groupId;
  const _FundTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundAsync = ref.watch(groupPrimaryFundProvider(groupId));
    return fundAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Text(
        errorMessage(e),
        style: GlassTypography.bodyMd(color: GlassColors.danger),
      ),
      data: (fund) {
        if (fund == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhóm chưa có quỹ chung nào.',
                style: GlassTypography.bodyMd(),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('fund-tab-go-settings'),
                onPressed: () =>
                    context.push('/group-settings', extra: groupId),
                child: const Text('Tạo quỹ chung trong Cài đặt nhóm'),
              ),
            ],
          );
        }
        return _FundEntriesAndSummary(groupId: groupId, fundId: fund.id);
      },
    );
  }
}

class _FundEntriesAndSummary extends ConsumerWidget {
  final String groupId;
  final String fundId;
  const _FundEntriesAndSummary({required this.groupId, required this.fundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(groupFundSummaryProvider((groupId, fundId)));
    final entriesAsync = ref.watch(groupFundEntriesProvider((groupId, fundId)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summaryAsync.maybeWhen(
          data: (summary) {
            if (summary.contributionsByMember.isEmpty)
              return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: summary.contributionsByMember
                    .map(
                      (m) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.memberName,
                                  style: GlassTypography.bodySm(),
                                ),
                                Text(
                                  'Đã góp: ${m.formattedAmount}',
                                  style: GlassTypography.labelNumeric(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        Text('Sổ quỹ', style: GlassTypography.headlineSm()),
        const SizedBox(height: 12),
        entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Text(
            errorMessage(e),
            style: GlassTypography.bodyMd(color: GlassColors.danger),
          ),
          data: (entries) {
            if (entries.isEmpty)
              return Text(
                'Chưa có dòng quỹ nào.',
                style: GlassTypography.bodyMd(),
              );
            return Column(
              children: entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.merchantName ??
                                        entry.categoryName ??
                                        entry.kind.label,
                                    style: GlassTypography.bodyMd(
                                      color: GlassColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${entry.memberName} · ${DateFormat('dd/MM').format(entry.transactedAt)}',
                                    style: GlassTypography.bodySm(),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${entry.isCredit ? '+' : '-'}${entry.formattedAmount}',
                              style: GlassTypography.labelNumeric(
                                color: entry.isCredit
                                    ? GlassColors.success
                                    : GlassColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
