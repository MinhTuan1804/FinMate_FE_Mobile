import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
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
    // Chế độ nháp là trạng thái dùng chung của controller: rời màn mà không tắt thì lịch sử ở nơi khác vẫn hiện nháp.
    // Hoãn một microtask vì dispose chạy giữa lúc cây widget đang dỡ, không được phát state mới ngay lúc đó.
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
      messenger.showSnackBar(const SnackBar(content: Text('Đã xác nhận giao dịch'), backgroundColor: AppColors.safe));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
      // Nháp có thể không còn hợp lệ ở BE (đã duyệt/bị xóa): tải lại để dòng cũ không nằm lại danh sách.
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
      messenger.showSnackBar(const SnackBar(content: Text('Đã xác nhận giao dịch'), backgroundColor: AppColors.safe));
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txState = ref.watch(transactionControllerProvider);
    final controller = ref.read(transactionControllerProvider.notifier);
    _controller = controller;
    final drafts = controller.draftsOnly;
    // Quay lại app: tải lại nháp SAU khi scope đã gọi xong flushQueue (tick), không chạy song song với nó.
    // Hạn chế: flushQueue chỉ lên lịch đẩy hàng đợi, server còn cần vài giây để AI tạo nháp, nên nháp mới có thể
    // chưa hiện ngay; kéo xuống hoặc "Tải lại" để lấy nốt.
    ref.listen(notificationFlushTickProvider, (_, __) {
      if (controller.draftsOnly) controller.loadTransactions();
    });
    final accessOff = drafts && ref.watch(notificationAccessEnabledProvider).valueOrNull == false;

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateTransactionBottomSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Ghi chép mới'),
      ),
      body: Column(
        children: [
          const FailedSyncBanner(),
          // Filter Chips (lọc phía server)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                for (final (label, type) in _filters) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: !drafts && controller.filter == type,
                    onSelected: (_) {
                      // Đang ở Chờ duyệt thì tắt chế độ nháp; chỉ đổi loại khi khác loại đang lưu để khỏi tải thừa
                      if (drafts) controller.setDraftsOnly(false);
                      if (!drafts || controller.filter != type) controller.setFilter(type);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  // Ngay sau "Tất cả" để còn thấy được trên màn hình hẹp (hàng chip cuộn ngang)
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

          const Divider(height: 1),

          if (accessOff) NotificationAccessCard(onOpenSettings: _openAccessSettings),

          Expanded(
            child: txState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 36, color: AppColors.danger),
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
              data: (transactions) {
                if (drafts) return _buildDrafts(context, transactions, controller);
                if (transactions.isEmpty) return _buildEmpty(context, isDark);

                // Nhóm theo ngày (giờ địa phương)
                final grouped = <String, List<TransactionEntity>>{};
                final dayFormatter = DateFormat('dd/MM/yyyy');
                for (final tx in transactions) {
                  grouped.putIfAbsent(dayFormatter.format(tx.date), () => []).add(tx);
                }

                return RefreshIndicator(
                  onRefresh: controller.loadTransactions,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final dayKey = grouped.keys.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
                            child: Text(
                              dayKey,
                              style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          ...grouped[dayKey]!.map((tx) => _buildTransactionTile(context, tx, isDark)),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrafts(BuildContext context, List<TransactionEntity> drafts, TransactionController controller) {
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
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: AppSpacing.md),
                // Offline cũng trả danh sách rỗng nên không khẳng định "không có nháp"
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
              padding: const EdgeInsets.only(bottom: 80),
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

  Widget _buildEmpty(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.receipt,
            size: 48,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 12),
          Text('Chưa có giao dịch nào', style: AppTypography.caption(context)),
        ],
      ),
    );
  }

  Widget _syncBadge(TransactionEntity tx) {
    if (tx.isSynced) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(left: 6),
      child: Icon(LucideIcons.cloudOff, size: 12, color: AppColors.warning),
    );
  }

  Widget _buildTransactionTile(BuildContext context, TransactionEntity tx, bool isDark) {
    // 1. Chuyển khoản nội bộ (BR-26, BR-27: Không tính vào chi tiêu/ngân sách)
    if (tx.isInternalTransfer) {
      return ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(LucideIcons.arrowLeftRight, size: 20, color: Colors.blueGrey),
        ),
        title: Text(
          tx.description.isNotEmpty ? tx.description : 'Chuyển tiền nội bộ',
          style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Nội bộ - Không tính chi tiêu',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.blueGrey),
              ),
            ),
            _syncBadge(tx),
          ],
        ),
        trailing: Text(
          tx.formattedAmount,
          style: AppTypography.tabular(
            AppTypography.bodyLarge(context).copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    // 2. Giao dịch Thu / Chi thông thường
    final isExpense = tx.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final prefix = isExpense ? '-' : '+';

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isExpense ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
          size: 20,
          color: color,
        ),
      ),
      title: Text(
        tx.description.isNotEmpty ? tx.description : (tx.categoryName ?? 'Giao dịch'),
        style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(tx.categoryName ?? 'Không phân loại', style: AppTypography.caption(context)),
          _syncBadge(tx),
        ],
      ),
      trailing: Text(
        '$prefix${tx.formattedAmount}',
        style: AppTypography.tabular(
          AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
