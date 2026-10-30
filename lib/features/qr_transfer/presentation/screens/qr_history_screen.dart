import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/qr_transfer/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';
import 'package:finmate/features/qr_transfer/presentation/controllers/qr_providers.dart';

/// Lịch sử quét QR: tab "Đã quét" (từng lần chuyển, đã khớp thông báo hay chưa) và tab "Người nhận" (danh mục FinMate đã nhớ cho từng người, sửa hoặc bỏ được mà không cần quét lại).
class QrHistoryScreen extends StatelessWidget {
  const QrHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lịch sử quét QR'),
          bottom: const TabBar(tabs: [Tab(text: 'Đã quét'), Tab(text: 'Người nhận')]),
        ),
        body: const TabBarView(children: [_TransfersTab(), _OverridesTab()]),
      ),
    );
  }
}

String _errorText(Object error) => error is ApiException ? error.message : 'Có lỗi xảy ra. Thử lại sau.';

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

class _TransfersTab extends ConsumerWidget {
  const _TransfersTab();

  Future<void> _cancel(BuildContext context, WidgetRef ref, QrTransfer item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hủy lần quét này?'),
        content: Text('Hủy lần chuyển ${formatVnd(BigInt.from(item.amount))} tới ${item.receiverAccountNumber}. Việc này không ảnh hưởng tiền thật, chỉ bỏ ghi nhận trong FinMate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Giữ lại')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Hủy lần quét')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(qrTransferRepositoryProvider).cancelTransfer(item.id);
      ref.invalidate(qrTransfersProvider);
    } on Object catch (e) {
      if (context.mounted) _toast(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(qrTransfersProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(qrTransfersProvider.future),
      child: transfers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(text: _errorText(e), actionLabel: 'Thử lại', onAction: () => ref.invalidate(qrTransfersProvider)),
        data: (items) => items.isEmpty
            ? const _Message(text: 'Chưa quét mã nào. Nút quét ở giữa thanh điều hướng sẽ mở camera.')
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                itemBuilder: (context, index) => _TransferTile(item: items[index], onCancel: () => _cancel(context, ref, items[index])),
              ),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.item, required this.onCancel});

  final QrTransfer item;
  final VoidCallback onCancel;

  ({IconData icon, Color color, String label}) _status(BuildContext context) {
    switch (item.status) {
      case QrTransferStatus.matched:
        return (icon: LucideIcons.check, color: AppColors.safe, label: 'Đã khớp giao dịch');
      case QrTransferStatus.cancelled:
        return (icon: LucideIcons.x, color: Theme.of(context).colorScheme.onSurfaceVariant, label: 'Đã hủy');
      case QrTransferStatus.pending:
        return item.isExpired
            ? (icon: LucideIcons.clock, color: AppColors.warning, label: 'Hết hạn, chưa thấy thông báo')
            : (icon: LucideIcons.clock, color: AppColors.warning, label: 'Đang chờ thông báo ngân hàng');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final when = DateFormat('dd/MM/yyyy HH:mm').format(item.scannedAt.toLocal());
    final title = '${item.senderBankName} → ${item.receiverBankName} • ${item.receiverAccountNumber}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMedium,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: ListTile(
        minVerticalPadding: AppSpacing.md,
        leading: Icon(status.icon, color: status.color),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            formatVnd(BigInt.from(item.amount)),
            if (item.receiverName != null) item.receiverName!,
            if (item.categoryName != null) item.categoryName!,
            status.label,
            when,
          ].join(' • '),
        ),
        trailing: item.status == QrTransferStatus.pending ? IconButton(tooltip: 'Hủy lần quét', icon: const Icon(LucideIcons.trash2, size: 20), onPressed: onCancel) : null,
      ),
    );
  }
}

class _OverridesTab extends ConsumerWidget {
  const _OverridesTab();

  Future<void> _edit(BuildContext context, WidgetRef ref, CounterpartyOverride item) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Đổi danh mục cho ${item.displayName ?? item.accountNumber}', style: AppTypography.h3(sheet))),
              for (final c in categories)
                ListTile(
                  minTileHeight: 52,
                  leading: Icon(categoryIcon(c.slug), size: 20),
                  title: Text(c.name),
                  trailing: c.id == item.categoryId ? const Icon(LucideIcons.check, size: 18) : null,
                  onTap: () => Navigator.pop(sheet, c.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen == item.categoryId) return;
    try {
      await ref.read(qrTransferRepositoryProvider).updateOverrideCategory(item.id, chosen);
      ref.invalidate(qrOverridesProvider);
    } on Object catch (e) {
      if (context.mounted) _toast(context, _errorText(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CounterpartyOverride item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Bỏ danh mục đã nhớ?'),
        content: Text('Lần chuyển tiếp theo tới ${item.accountNumber} sẽ hỏi lại danh mục như lần đầu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Giữ lại')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Bỏ')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(qrTransferRepositoryProvider).deleteOverride(item.id);
      ref.invalidate(qrOverridesProvider);
    } on Object catch (e) {
      if (context.mounted) _toast(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(qrOverridesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(qrOverridesProvider.future),
      child: overrides.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(text: _errorText(e), actionLabel: 'Thử lại', onAction: () => ref.invalidate(qrOverridesProvider)),
        data: (items) => items.isEmpty
            ? const _Message(text: 'Chưa nhớ người nhận nào. FinMate nhớ khi bạn chọn một danh mục lúc quét, hoặc sửa danh mục của giao dịch đã khớp mã QR.')
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: AppSpacing.roundedMedium,
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: ListTile(
                      minVerticalPadding: AppSpacing.md,
                      title: Text('${item.bankName} • ${item.accountNumber}'),
                      subtitle: Text([if (item.displayName != null) item.displayName!, 'Danh mục: ${item.categoryName}'].join(' • ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(tooltip: 'Đổi danh mục', icon: const Icon(LucideIcons.pencil, size: 20), onPressed: () => _edit(context, ref, item)),
                          IconButton(tooltip: 'Bỏ danh mục đã nhớ', icon: const Icon(LucideIcons.trash2, size: 20), onPressed: () => _delete(context, ref, item)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Cuộn được để kéo-làm-mới hoạt động cả khi danh sách rỗng.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(text, textAlign: TextAlign.center, style: AppTypography.body(context)),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(child: OutlinedButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}
