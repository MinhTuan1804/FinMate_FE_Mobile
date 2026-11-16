import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_edit_sheet.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_transaction_tile.dart';
import 'package:finmate/features/transactions/presentation/widgets/failed_sync_banner.dart';
import 'package:finmate/features/transactions/presentation/widgets/notification_access_card.dart';
import 'package:finmate/shared/widgets/glass/main_bottom_nav.dart';

/// Tổng chi/thu của một khoảng ngày bất kỳ (máy chủ tính, không cộng từ các trang đã tải).
/// Tải lại khi giao dịch mới nhất đổi (thêm/xóa/xác nhận giao dịch).
final _periodSummaryProvider = FutureProvider.autoDispose
    .family<MonthlySummary, (DateTime, DateTime)>((ref, range) {
      if (ref.watch(currentUserIdProvider) == null) return MonthlySummary.empty;
      ref.watch(
        transactionControllerProvider.select(
          (s) => s.valueOrNull?.firstOrNull?.id,
        ),
      );
      return ref
          .watch(reportsRepositoryProvider)
          .getPeriodSummary(from: range.$1, to: range.$2);
    });

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

  /// Khoảng ngày đang xem (gồm cả hai đầu); null = tháng hiện tại, chưa lọc danh sách
  DateTimeRange? _range;

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
    // Bộ lọc ngày cũng là trạng thái dùng chung: trả về không lọc khi rời màn
    if (controller != null && _range != null) {
      Future.microtask(() {
        if (controller.mounted) controller.setRange(null, null);
      });
    }
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
      await ref
          .read(transactionControllerProvider.notifier)
          .confirmDraft(draft.id);
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
      // Nháp có thể không còn hợp lệ ở BE (đã duyệt/bị xóa): tải lại để dòng cũ không nằm lại danh sách.
      if (mounted)
        ref.read(transactionControllerProvider.notifier).loadTransactions();
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

  /// Mở hộp thoại chia sẻ vào nhóm (chưa chia sẻ) hoặc hộp thoại xác nhận bỏ chia sẻ (đã chia sẻ).
  Future<void> _openShareSheet(TransactionEntity tx) async {
    if (tx.groupId == null) {
      final picked = await showDialog<(String, String?)>(
        context: context,
        builder: (_) => const _ShareToGroupDialog(),
      );
      if (picked == null || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(transactionControllerProvider.notifier)
            .shareToGroup(
              id: tx.id,
              groupId: picked.$1,
              groupCategoryId: picked.$2,
            );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã chia sẻ giao dịch vào nhóm'),
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
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bỏ chia sẻ giao dịch'),
          content: const Text(
            'Giao dịch sẽ không còn hiển thị trong nhóm. Bạn có chắc chắn?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              key: const ValueKey('confirm-unshare-group'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Bỏ chia sẻ'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(transactionControllerProvider.notifier)
            .unshareFromGroup(tx.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã bỏ chia sẻ giao dịch'),
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
      }
    }
  }

  Future<void> _openAccessSettings() async {
    try {
      await ref
          .read(notificationBridgeProvider)
          .openNotificationAccessSettings();
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
    final accessOff =
        drafts &&
        ref.watch(notificationAccessEnabledProvider).valueOrNull == false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Lịch sử giao dịch'),
        actions: [
          IconButton(
            key: const ValueKey('open-transfer'),
            tooltip: 'Chuyển tiền giữa ví',
            icon: const Icon(LucideIcons.arrowLeftRight),
            onPressed: () => context.push('/transfer'),
          ),
          IconButton(
            key: const ValueKey('open-scan-receipt'),
            tooltip: 'Quét hóa đơn',
            icon: const Icon(LucideIcons.scanLine),
            onPressed: () => context.push('/scan-receipt'),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 1),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateTransactionBottomSheet.show(context),
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Ghi chép mới'),
      ),
      body: AmbientGlassBackground(
        child: Column(
          children: [
            const FailedSyncBanner(),
            // Filter Chips (lọc phía server)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  for (final (label, type) in _filters) ...[
                    _filterChip(
                      context,
                      label,
                      !drafts && controller.filter == type,
                      () {
                        // Đang ở Chờ duyệt thì tắt chế độ nháp; chỉ đổi loại khi khác loại đang lưu để khỏi tải thừa
                        if (drafts) controller.setDraftsOnly(false);
                        if (!drafts || controller.filter != type)
                          controller.setFilter(type);
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    // Ngay sau "Tất cả" để còn thấy được trên màn hình hẹp (hàng chip cuộn ngang)
                    if (type == null && label == _filters.first.$1) ...[
                      _filterChip(context, 'Chờ duyệt', drafts, () {
                        if (!drafts) controller.setDraftsOnly(true);
                        setState(() {});
                      }),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                data: (transactions) {
                  if (drafts)
                    return _buildDrafts(context, transactions, controller);
                  if (transactions.isEmpty) return _buildEmpty(context, isDark);

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
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: grouped.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Thẻ tổng tháng chỉ hiện khi xem toàn bộ, không lọc loại
                          return controller.filter == null
                              ? _monthCard(context)
                              : const SizedBox.shrink();
                        }
                        final dayKey = grouped.keys.elementAt(index - 1);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dayHeader(context, grouped[dayKey]!),
                            ...grouped[dayKey]!.map(
                              (tx) =>
                                  _buildTransactionTile(context, tx, isDark),
                            ),
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
      ),
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
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
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
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

  Widget _filterChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final action = AppColors.activeFill(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      shape: const StadiumBorder(),
      selectedColor: action,
      backgroundColor: AppColors.surfaceSubtle(context).withValues(alpha: 0.5),
      side: BorderSide(color: AppColors.glassBorder(context)),
      labelStyle: AppTypography.caption(context).copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
            ? AppColors.activeFg(context)
            : AppColors.textSecondary(context),
      ),
    );
  }

  /// Nhãn ngày của một nhóm giao dịch
  Widget _dayHeader(BuildContext context, List<TransactionEntity> day) {
    final now = DateTime.now();
    final d = day.first.date;
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final y = now.subtract(const Duration(days: 1));
    final isYesterday =
        d.year == y.year && d.month == y.month && d.day == y.day;
    final dayMonth = '${d.day.toString().padLeft(2, '0')} Th${d.month}';
    final label = isToday
        ? 'Hôm nay, $dayMonth'
        : (isYesterday
              ? 'Hôm qua, $dayMonth'
              : DateFormat('dd/MM/yyyy').format(d));
    final caption = AppTypography.caption(context);
    // Tổng chi/thu đã có ở thẻ tổng phía trên nên tiêu đề ngày chỉ còn nhãn ngày.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: caption.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static DateTimeRange _monthRange(DateTime m) => DateTimeRange(
    start: DateTime(m.year, m.month),
    end: DateTime(m.year, m.month + 1, 0),
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Tháng 11, 2026" khi khoảng là đúng một tháng dương lịch, ngược lại "01/11/2026 – 16/11/2026"
  static String _rangeLabel(DateTimeRange r) {
    final isMonth = r.start.day == 1 && _sameDay(r.end, _monthRange(r.start).end);
    if (isMonth) return 'Tháng ${r.start.month}, ${r.start.year}';
    final f = DateFormat('dd/MM/yyyy');
    return '${f.format(r.start)} – ${f.format(r.end)}';
  }

  /// Chọn khoảng thời gian: tháng này, tháng trước, năm nay, năm trước, hoặc tự chọn từ ngày … đến ngày …; lọc cả thẻ tổng lẫn danh sách
  Future<void> _pickRange(DateTimeRange current) async {
    final now = DateTime.now();
    final presets = <(String, DateTimeRange)>[
      ('Tháng này', _monthRange(now)),
      ('Tháng trước', _monthRange(DateTime(now.year, now.month - 1))),
      ('Năm nay', DateTimeRange(start: DateTime(now.year), end: DateTime(now.year, 12, 31))),
      ('Năm trước', DateTimeRange(start: DateTime(now.year - 1), end: DateTime(now.year - 1, 12, 31))),
    ];
    // Giá trị "custom" là DateTimeRange rỗng đặc biệt: dùng null để phân biệt với đóng sheet
    final picked = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in presets)
              ListTile(
                title: Text(p.$1),
                subtitle: Text(_rangeLabel(p.$2)),
                trailing:
                    _sameDay(p.$2.start, current.start) &&
                        _sameDay(p.$2.end, current.end)
                    ? const Icon(LucideIcons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(ctx, p.$2),
              ),
            ListTile(
              key: const ValueKey('range-custom'),
              leading: const Icon(LucideIcons.calendarRange, size: 18),
              title: const Text('Chọn khoảng ngày…'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    DateTimeRange? range;
    if (picked is DateTimeRange) {
      range = picked;
    } else {
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: current,
        helpText: 'Chọn khoảng thời gian',
        saveText: 'Áp dụng',
      );
    }
    if (range == null || !mounted) return;
    setState(() => _range = range);
    ref
        .read(transactionControllerProvider.notifier)
        .setRange(range.start, range.end);
  }

  /// Thẻ tổng chi/thu của khoảng đang chọn, lấy từ máy chủ (không cộng từ các trang đã tải)
  Widget _monthCard(BuildContext context) {
    final now = DateTime.now();
    final range = _range ?? _monthRange(now);
    final summary = ref
        .watch(_periodSummaryProvider((range.start, range.end)))
        .valueOrNull;
    final days = range.duration.inDays + 1;
    final caption = AppTypography.caption(context);
    Widget total(String label, Color dot, String value, Color valueColor) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: caption),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabular(
                  AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700, color: valueColor),
                ),
              ),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? AppColors.glassFillDark
            : AppColors.glassFillLight,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Material(
                color: AppColors.surface(context).withValues(alpha: 0.8),
                shape: StadiumBorder(
                  side: BorderSide(color: AppColors.glassBorder(context)),
                ),
                child: InkWell(
                  key: const ValueKey('month-picker'),
                  customBorder: const StadiumBorder(),
                  onTap: () => _pickRange(range),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.calendar, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _rangeLabel(range),
                            style: AppTypography.bodyMedium(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronDown, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$days NGÀY',
                style: caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.55,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              total(
                'Tổng chi',
                AppColors.expenseOn(context),
                summary == null ? '—' : formatVnd(summary.totalSpentCents),
                AppColors.expenseOn(context),
              ),
              total(
                'Tổng thu',
                AppColors.incomeOn(context),
                summary == null
                    ? '—'
                    : '+${formatVnd(summary.totalIncomeCents)}',
                AppColors.incomeOn(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    TransactionEntity tx,
    bool isDark,
  ) {
    final accounts =
        ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final accountName = accounts
        .where((a) => a.id == tx.accountId)
        .map((a) => a.name)
        .firstOrNull;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final slug = categories
        .where((c) => c.id == tx.categoryId)
        .map((c) => c.slug)
        .firstOrNull;
    final secondary = AppTypography.caption(context);
    final isTransfer = tx.isInternalTransfer;
    final isExpense = tx.type == TransactionType.expense;
    final color = isTransfer
        ? AppColors.transferOn(context)
        : (isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context));
    final prefix = isTransfer ? '' : (isExpense ? '-' : '+');
    final title = tx.description.isNotEmpty
        ? tx.description
        : (isTransfer
              ? 'Chuyển tiền nội bộ'
              : (tx.categoryName ?? 'Giao dịch'));
    final time = DateFormat('HH:mm').format(tx.date);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassFillDark : AppColors.glassFillLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/transaction-detail', extra: tx),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder(context)),
                ),
                child: Icon(
                  isTransfer ? LucideIcons.arrowLeftRight : categoryIcon(slug),
                  size: 20,
                  color: AppColors.slateOn(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isTransfer
                                ? 'Nội bộ - Không tính chi tiêu'
                                : '${tx.categoryName ?? 'Không phân loại'} • $time',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: secondary,
                          ),
                        ),
                        _syncBadge(tx),
                        if (!isTransfer)
                          SizedBox(
                            width: 32,
                            height: 24,
                            child: IconButton(
                              key: ValueKey('share-group-${tx.id}'),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                LucideIcons.users,
                                size: 16,
                                color: tx.groupId != null
                                    ? AppColors.primaryAction(context)
                                    : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                              ),
                              tooltip: tx.groupId != null
                                  ? 'Đã chia sẻ vào nhóm'
                                  : 'Chia sẻ vào nhóm',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openShareSheet(tx),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${tx.formattedAmount}',
                    style: AppTypography.tabular(
                      AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  if (accountName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: Text(
                        accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: secondary.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slateOn(context),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại chọn nhóm (+ danh mục nhóm tùy chọn) để chia sẻ một giao dịch.
/// Trả về `(groupId, groupCategoryId)` khi xác nhận, `null` khi hủy. Tự watch danh sách
/// nhóm/danh mục nhóm (không nhận qua constructor) để đúng trạng thái tải/lỗi hiện tại.
class _ShareToGroupDialog extends ConsumerStatefulWidget {
  const _ShareToGroupDialog();

  @override
  ConsumerState<_ShareToGroupDialog> createState() =>
      _ShareToGroupDialogState();
}

class _ShareToGroupDialogState extends ConsumerState<_ShareToGroupDialog> {
  String? _groupId;
  String? _groupCategoryId;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsControllerProvider);

    return AlertDialog(
      title: const Text('Chia sẻ vào nhóm'),
      content: groupsAsync.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Text(errorMessage(e)),
        data: (groups) => groups.isEmpty
            ? const Text('Bạn chưa tham gia nhóm nào.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('share-group-select'),
                      initialValue: _groupId,
                      decoration: const InputDecoration(labelText: 'Nhóm'),
                      items: [
                        for (final g in groups)
                          DropdownMenuItem(value: g.id, child: Text(g.name)),
                      ],
                      onChanged: (v) => setState(() {
                        _groupId = v;
                        _groupCategoryId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (_groupId != null)
                      ref
                          .watch(groupCategoriesProvider(_groupId!))
                          .when(
                            data: (cats) => DropdownButtonFormField<String>(
                              key: const ValueKey('share-category-select'),
                              initialValue: _groupCategoryId,
                              decoration: const InputDecoration(
                                labelText: 'Danh mục nhóm (tùy chọn)',
                              ),
                              items: [
                                for (final c in cats)
                                  DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _groupCategoryId = v),
                            ),
                            loading: () => const SizedBox(
                              height: 48,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          key: const ValueKey('confirm-share-group'),
          onPressed: _groupId == null
              ? null
              : () => Navigator.pop(context, (_groupId!, _groupCategoryId)),
          child: const Text('Chia sẻ'),
        ),
      ],
    );
  }
}
