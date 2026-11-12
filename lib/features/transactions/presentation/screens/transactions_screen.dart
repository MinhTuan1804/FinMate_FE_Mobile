import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/dashboard/presentation/widgets/app_bottom_nav.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_edit_sheet.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_transaction_tile.dart';
import 'package:finmate/features/transactions/presentation/widgets/failed_sync_banner.dart';
import 'package:finmate/features/transactions/presentation/widgets/notification_access_card.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scrollController = ScrollController();

  /// Nháp đang gửi yêu cầu xác nhận (khoá nút của đúng tile đó)
  final _busyDrafts = <String>{};

  // dispose không dùng được ref nữa nên giữ controller của lần build gần nhất
  TransactionController? _controller;

  static const _filters = <(String, TransactionType?)>[
    ('Tất cả', null),
    ('Chi tiêu', TransactionType.expense),
    ('Thu nhập', TransactionType.income),
    ('Chuyển tiền nội bộ', TransactionType.transfer),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    final controller = _controller;
    if (controller != null && controller.draftsOnly) {
      Future.microtask(() {
        if (controller.mounted) controller.setDraftsOnly(false);
      });
    }
    super.dispose();
  }

  Future<void> _confirm(TransactionEntity draft) async {
    if (!_busyDrafts.add(draft.id)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(transactionControllerProvider.notifier).confirmDraft(draft.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận giao dịch'),
          backgroundColor: AppColors.safe,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
      if (mounted) ref.read(transactionControllerProvider.notifier).loadTransactions();
    } finally {
      _busyDrafts.remove(draft.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _edit(TransactionEntity draft) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await DraftEditSheet.show(context, draft);
    if (confirmed == true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận giao dịch'),
          backgroundColor: AppColors.safe,
        ),
      );
    }
  }

  Future<void> _openAccessSettings() async {
    try {
      await ref.read(notificationBridgeProvider).openNotificationAccessSettings();
    } catch (_) {
      // Không mở được màn cài đặt thì người dùng tự vào; không có gì để báo thêm
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionControllerProvider);
    final controller = ref.read(transactionControllerProvider.notifier);
    _controller = controller;
    final drafts = controller.draftsOnly;
    ref.listen(notificationFlushTickProvider, (_, __) {
      if (controller.draftsOnly) controller.loadTransactions();
    });
    final accessOff =
        drafts && ref.watch(notificationAccessEnabledProvider).valueOrNull == false;

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateTransactionBottomSheet.show(context),
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        elevation: 2,
        shape: const StadiumBorder(),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Ghi chép mới',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: AmbientGlassBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FailedSyncBanner(),
            // Zenvest Filter Pill Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              child: Row(
                children: [
                  for (final (label, type) in _filters) ...[
                    ChoiceChip(
                      label: Text(label),
                      selected: !drafts && controller.filter == type,
                      onSelected: (_) {
                        if (drafts) controller.setDraftsOnly(false);
                        if (!drafts || controller.filter != type) {
                          controller.setFilter(type);
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    if (type == null && label == _filters.first.$1) ...[
                      ChoiceChip(
                        label: const Text('Chờ duyệt'),
                        selected: drafts,
                        onSelected: (_) {
                          if (!drafts) controller.setDraftsOnly(true);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ],
              ),
            ),

            if (accessOff)
              NotificationAccessCard(onOpenSettings: _openAccessSettings),

            Expanded(
              child: txState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ZenvestSurfaceSheet(
                      showDragHandle: false,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            size: 36,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 8),
                          Text(errorMessage(err), textAlign: TextAlign.center),
                          TextButton(
                            onPressed: controller.loadTransactions,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (transactions) {
                  if (drafts) {
                    return _buildDrafts(context, transactions, controller);
                  }
                  if (transactions.isEmpty) return _buildEmpty(context);

                  // Nhóm theo ngày (giờ địa phương)
                  final grouped = <String, List<TransactionEntity>>{};
                  final dayFormatter = DateFormat('dd/MM/yyyy');
                  for (final tx in transactions) {
                    grouped
                        .putIfAbsent(dayFormatter.format(tx.date), () => [])
                        .add(tx);
                  }

                  return RefreshIndicator(
                    onRefresh: controller.loadTransactions,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final dayKey = grouped.keys.elementAt(index);
                        final dayTxs = grouped[dayKey]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: ZenvestSurfaceSheet(
                            showDragHandle: index == 0,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    dayKey,
                                    style: AppTypography.caption(context)
                                        .copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (var i = 0; i < dayTxs.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      color: AppColors.border(context)
                                          .withValues(alpha: 0.55),
                                    ),
                                  _buildTransactionTile(context, dayTxs[i]),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildDrafts(
    BuildContext context,
    List<TransactionEntity> drafts,
    TransactionController controller,
  ) {
    return RefreshIndicator(
      onRefresh: controller.loadTransactions,
      child: drafts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Icon(
                  LucideIcons.inbox,
                  size: 48,
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Hiện chưa hiển thị giao dịch nào chờ duyệt. Kéo xuống hoặc bấm Tải lại để cập nhật (cần có kết nối mạng).',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: controller.loadTransactions,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Tải lại'),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: drafts.length,
              itemBuilder: (context, index) {
                final draft = drafts[index];
                return DraftTransactionTile(
                  key: ValueKey(draft.id),
                  draft: draft,
                  busy: _busyDrafts.contains(draft.id),
                  onConfirm: () => _confirm(draft),
                  onEdit: () => _edit(draft),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.receipt,
            size: 48,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text('Chưa có giao dịch nào', style: AppTypography.caption(context)),
        ],
      ),
    );
  }

  Widget _syncBadge(TransactionEntity tx) {
    if (tx.isSynced) return const SizedBox.shrink();
    return const Icon(LucideIcons.cloudOff, size: 13, color: AppColors.warning);
  }

  Widget _buildTransactionTile(BuildContext context, TransactionEntity tx) {
    final timeStr = DateFormat('HH:mm').format(tx.date);

    // 1. Chuyển khoản nội bộ (BR-26, BR-27: Không tính vào chi tiêu/ngân sách)
    if (tx.isInternalTransfer) {
      return ZenvestTransactionTile(
        onTap: () => context.push('/transactions/detail', extra: tx),
        icon: LucideIcons.arrowLeftRight,
        iconColor: AppColors.transfer,
        title: tx.description.isNotEmpty
            ? tx.description
            : 'Chuyển tiền nội bộ',
        categoryLabel: 'Nội bộ - Không tính chi tiêu',
        timeLabel: timeStr,
        amountText: tx.formattedAmount,
        amountColor: AppColors.textPrimary(context),
        typeLabel: 'Chuyển khoản',
        typeColor: AppColors.transfer,
        badgeWidget: tx.isSynced ? null : _syncBadge(tx),
      );
    }

    // 2. Giao dịch Thu / Chi thông thường
    final isExpense = tx.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final prefix = isExpense ? '-' : '+';

    return ZenvestTransactionTile(
      onTap: () => context.push('/transactions/detail', extra: tx),
      icon: isExpense ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
      iconColor: color,
      title: tx.description.isNotEmpty
          ? tx.description
          : (tx.categoryName ?? 'Giao dịch'),
      categoryLabel: tx.categoryName ?? 'Không phân loại',
      timeLabel: timeStr,
      amountText: '$prefix${tx.formattedAmount}',
      amountColor: AppColors.textPrimary(context),
      typeLabel: isExpense ? 'Chi tiêu' : 'Thu nhập',
      typeColor: color,
      badgeWidget: tx.isSynced ? null : _syncBadge(tx),
    );
  }
}
