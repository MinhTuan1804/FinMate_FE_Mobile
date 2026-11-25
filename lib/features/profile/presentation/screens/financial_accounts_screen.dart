import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';

const _maskedAmount = '••••••••';

/// Màn H7: Tài khoản & Nguồn tiền (theo Figma). Danh sách gom theo loại, số liệu lấy từ API; đổi tên, bật/tắt theo dõi và xóa qua menu từng hàng.
/// "Mặc định", mức tăng trong tháng và nút "Cập nhật số dư" của tiền mặt chưa có ở BE nên không hiển thị.
class FinancialAccountsScreen extends ConsumerStatefulWidget {
  const FinancialAccountsScreen({super.key});

  @override
  ConsumerState<FinancialAccountsScreen> createState() => _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends ConsumerState<FinancialAccountsScreen> {
  bool _hidden = false;

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : null));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      _toast(success);
    } on AccountsReloadFailedException {
      // Hành động (đổi tên/bật-tắt/xóa) đã thành công ở BE — chỉ việc tải lại danh sách sau đó bị
      // lỗi, không phải lỗi của chính hành động. Báo rõ cả 2 vế, không đẩy cả màn vào trạng thái lỗi.
      _toast('$success Nhưng không tải lại được danh sách — kéo để làm mới.', error: true);
    } on Object catch (e) {
      _toast(errorMessage(e), error: true);
    }
  }

  Future<void> _rename(FinancialAccount a) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameAccountDialog(initialName: a.name),
    );
    if (name == null || name.isEmpty || name == a.name || !mounted) return;
    await _run(() => ref.read(accountsControllerProvider.notifier).rename(a.id, name), 'Đã đổi tên tài khoản.');
  }

  Future<void> _delete(FinancialAccount a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Xóa "${a.name}"?'),
        content: const Text('Tài khoản sẽ bị xóa khỏi danh sách nguồn tiền. Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Giữ lại')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(accountsControllerProvider.notifier).delete(a.id), 'Đã xóa tài khoản.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(accountsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản & Nguồn tiền'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [
          IconButton(
            key: const ValueKey('add-account-top'),
            tooltip: 'Thêm tài khoản',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push('/profile/financial-accounts/add'),
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () => ref.read(accountsControllerProvider.notifier).load(),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(errorMessage(e), textAlign: TextAlign.center, style: AppTypography.body(context)),
                const SizedBox(height: AppSpacing.lg),
                Center(child: OutlinedButton(onPressed: () => ref.read(accountsControllerProvider.notifier).load(), child: const Text('Thử lại'))),
              ],
            ),
            data: (accounts) => _content(context, accounts),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<FinancialAccount> accounts) {
    final total = accounts.fold(BigInt.zero, (sum, a) => sum + a.balanceCents);
    final monitored = accounts.where((a) => a.isMonitored).length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        LiquidGlassCard(
          variant: LiquidGlassVariant.iridescentHero,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('TỔNG TÀI SẢN KHẢ DỤNG', style: AppTypography.sectionLabel(context))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.inset(context, 0.8), borderRadius: AppSpacing.roundedPill),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.safe, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$monitored/${accounts.length} đang theo dõi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _hidden ? _maskedAmount : formatVnd(total),
                      key: const ValueKey('total-balance'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayBalance(context).copyWith(fontSize: 32, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', FontWeight.w800.value.toDouble())]),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('toggle-hide'),
                    tooltip: _hidden ? 'Hiện số dư' : 'Ẩn số dư',
                    icon: Icon(_hidden ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Chưa có tài khoản nào. Bấm "Thêm tài khoản / nguồn tiền mới" để bắt đầu theo dõi.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context),
            ),
          ),
        for (final type in AccountType.values) ..._section(context, type, accounts.where((a) => a.type == type).toList()),
        const SizedBox(height: 8),
        LiquidGlassCard(
          variant: LiquidGlassVariant.subtle,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.textSecondary(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Không lưu mật khẩu ngân hàng', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('FinMate chỉ ghi nhận số dư và giao dịch bạn cho phép.', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LiquidGlassPillButton(
          key: const ValueKey('add-account-bottom'),
          label: 'Thêm tài khoản / nguồn tiền mới',
          icon: LucideIcons.circlePlus,
          isFullWidth: true,
          onPressed: () => context.push('/profile/financial-accounts/add'),
        ),
      ],
    );
  }

  List<Widget> _section(BuildContext context, AccountType type, List<FinancialAccount> items) {
    if (items.isEmpty) return const [];
    final title = switch (type) {
      AccountType.bank => 'Ngân hàng liên kết',
      AccountType.eWallet => 'Ví điện tử',
      AccountType.cash => 'Tiền mặt',
    };
    final icon = switch (type) {
      AccountType.bank => LucideIcons.landmark,
      AccountType.eWallet => LucideIcons.wallet,
      AccountType.cash => LucideIcons.banknote,
    };
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary(context)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700))),
            Text(type == AccountType.bank ? '${items.length} tài khoản' : '${items.length} ví', style: AppTypography.caption(context).copyWith(fontSize: 12)),
          ],
        ),
      ),
      for (final a in items) _row(context, a),
    ];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _row(BuildContext context, FinancialAccount a) {
    final isCash = a.type == AccountType.cash;
    final statusColor = isCash ? AppColors.textMuted(context) : (a.isMonitored ? AppColors.safe : AppColors.textMuted(context));
    final status = isCash ? 'Tự kiểm đếm' : (a.isMonitored ? 'Tự động đồng bộ' : 'Chưa theo dõi');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassCard(
        variant: LiquidGlassVariant.subtle, // dòng trong list: không blur từng item
        key: ValueKey('account-${a.id}'),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.18), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(_initials(a.name), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.slateOn(context))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(a.providerName ?? a.type.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(context).copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _hidden ? _maskedAmount : formatVnd(a.balanceCents),
                  style: AppTypography.tabular(AppTypography.body(context).copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
              ],
            ),
            PopupMenuButton<String>(
              key: ValueKey('menu-${a.id}'),
              tooltip: 'Tùy chọn cho ${a.name}',
              icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
              onSelected: (v) {
                switch (v) {
                  case 'rename':
                    _rename(a);
                  case 'monitor':
                    _run(
                      () => ref.read(accountsControllerProvider.notifier).setMonitoring(a.id, !a.isMonitored),
                      a.isMonitored ? 'Đã tắt theo dõi tự động.' : 'Đã bật theo dõi tự động.',
                    );
                  case 'delete':
                    _delete(a);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                if (!isCash) PopupMenuItem(value: 'monitor', child: Text(a.isMonitored ? 'Tắt theo dõi tự động' : 'Bật theo dõi tự động')),
                const PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog đổi tên tài khoản — TextEditingController do CHÍNH State của dialog sở hữu, chỉ dispose
/// khi State này bị gỡ khỏi cây widget (sau khi hiệu ứng đóng của AlertDialog chạy xong). Trước
/// đây controller được tạo ở màn cha và `dispose()` ngay sau khi `await showDialog` trả về — lúc đó
/// TextField bên trong vẫn còn đang animate ra (dialog đang transition đóng), dispose sớm làm crash
/// "A TextEditingController was used after being disposed."
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
      content: TextField(controller: _controller, autofocus: true, decoration: const InputDecoration(labelText: 'Tên gợi nhớ')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Lưu')),
      ],
    );
  }
}
