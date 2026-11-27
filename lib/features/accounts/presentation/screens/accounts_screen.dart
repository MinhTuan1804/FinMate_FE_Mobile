import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/data/data_coverage_repository.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';
import 'package:finmate/features/accounts/presentation/widgets/data_coverage_banner.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Màn quản lý tài khoản/ví: đổi tên, bật/tắt theo dõi, xem số dư mới nhất, xóa.
/// Đơn giản để test nhanh các API còn thiếu (update/toggle-monitoring/balance/delete).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, FinancialAccount account) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameAccountDialog(initialName: account.name),
    );
    if (newName == null || newName.isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountsControllerProvider.notifier).rename(account.id, newName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _toggleMonitoring(BuildContext context, WidgetRef ref, FinancialAccount account, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountsControllerProvider.notifier).setMonitoring(account.id, on);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  /// Lấy số dư mới nhất rồi tải lại danh sách, để số hiển thị trên thẻ cũng cập nhật theo
  /// (không chỉ hiện trong snackbar) — tránh người dùng thấy 2 số khác nhau trên cùng màn hình.
  Future<void> _showBalance(BuildContext context, WidgetRef ref, FinancialAccount account) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = ref.read(accountsControllerProvider.notifier);
      final balance = await controller.getBalance(account.id);
      await controller.load();
      messenger.showSnackBar(SnackBar(content: Text('${account.name}: ${formatVnd(balance.balanceCents)}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FinancialAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text('Xóa "${account.name}" khỏi FinMate. Giao dịch đã ghi nhận vẫn được giữ lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountsControllerProvider.notifier).delete(account.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsState = ref.watch(accountsControllerProvider);
    // Chỉ là thông tin phụ: chưa tải xong hoặc lỗi thì không hiện gì, màn hình vẫn dùng bình thường.
    final coverage = ref.watch(dataCoverageProvider).valueOrNull;
    final banner = coverage == null ? null : dataCoverageBanner(context, coverage);

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản & ví')),
      body: accountsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(errorMessage(e), style: AppTypography.body(context))),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(child: Text('Chưa có tài khoản nào.', style: AppTypography.body(context)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length + (banner == null ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (banner != null && index == 0) return banner;
              final account = accounts[index - (banner == null ? 0 : 1)];
              final note = account.isMonitored ? _coverageNote(context, coverage?.forAccount(account.id)) : null;
              return Container(
                key: ValueKey('account-${account.id}'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: AppSpacing.roundedMedium,
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.wallet, color: AppColors.primaryAction(context), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(account.name, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                              Text(account.type.label, style: AppTypography.caption(context)),
                            ],
                          ),
                        ),
                        Text(formatVnd(account.balanceCents), style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (note != null) ...[const SizedBox(height: 8), note],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              key: ValueKey('monitoring-${account.id}'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: account.isMonitored,
                              onChanged: (on) => _toggleMonitoring(context, ref, account, on),
                              title: Text('Theo dõi tự động', style: AppTypography.caption(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        AsyncActionBuilder(
                          onPressed: () => _showBalance(context, ref, account),
                          builder: (_, onTap, running) => TextButton.icon(
                            onPressed: onTap,
                            icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.refreshCw, size: 16),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Xem số dư mới nhất', maxLines: 1)),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          key: ValueKey('rename-${account.id}'),
                          tooltip: 'Đổi tên',
                          onPressed: () => _rename(context, ref, account),
                          icon: const Icon(LucideIcons.pencil, size: 18),
                        ),
                        IconButton(
                          key: ValueKey('delete-${account.id}'),
                          tooltip: 'Xóa',
                          onPressed: () => _delete(context, ref, account),
                          icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Ghi chú dưới một ví đang theo dõi khi BE thấy nó im lặng bất thường hoặc chưa đồng bộ kịp. `ok`, ví ít dùng
/// (`notEnoughData`) và trạng thái chưa rõ không hiện gì: không báo động vô cớ.
Widget? _coverageNote(BuildContext context, AccountCoverage? coverage) {
  if (coverage == null) return null;
  final String text;
  switch (coverage.status) {
    case AccountCoverageStatus.silent:
      text = coverage.notificationsOff
          ? 'Không thấy thông báo từ ${coverage.silentDays} ngày. Thông báo của app này đang tắt trên máy, hãy bật lại.'
          : 'Không thấy thông báo từ ${coverage.silentDays} ngày. Kiểm tra app ngân hàng còn bật thông báo không.';
    case AccountCoverageStatus.uploadGap:
      text = 'Máy đã nhận thông báo của ví này nhưng chưa đồng bộ lên FinMate. Mở app để đồng bộ.';
    case AccountCoverageStatus.ok || AccountCoverageStatus.notEnoughData || AccountCoverageStatus.unknown:
      return null;
  }
  return Row(
    key: ValueKey('coverage-note-${coverage.accountId}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.warning),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: AppTypography.caption(context))),
    ],
  );
}

/// Dialog đổi tên tài khoản — TextEditingController do CHÍNH State của dialog sở hữu, chỉ dispose
/// khi State này bị gỡ khỏi cây widget (sau khi hiệu ứng đóng của AlertDialog chạy xong). Cùng
/// pattern/lý do với `_RenameAccountDialog` trong `financial_accounts_screen.dart` — xem comment ở
/// đó để biết đầy đủ lý do (crash "TextEditingController used after being disposed" nếu dispose
/// ngay khi `showDialog` trả về trong lúc dialog còn đang animate đóng).
class _RenameAccountDialog extends StatefulWidget {
  final String initialName;
  const _RenameAccountDialog({required this.initialName});

  @override
  State<_RenameAccountDialog> createState() => _RenameAccountDialogState();
}

class _RenameAccountDialogState extends State<_RenameAccountDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên tài khoản'),
      content: TextField(controller: _controller, autofocus: true, decoration: const InputDecoration(labelText: 'Tên hiển thị')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Lưu')),
      ],
    );
  }
}
