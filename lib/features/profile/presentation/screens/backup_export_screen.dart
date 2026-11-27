import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/profile/data/data_export_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Số giao dịch trên máy còn chờ gửi lên máy chủ (đọc từ hàng đợi đồng bộ cục bộ).
final _pendingSyncProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(databaseProvider).pendingSyncCount());

enum _Range { month, quarter, year }

/// Màn H5: Sao lưu & Xuất dữ liệu (theo Figma). Phần trạng thái đồng bộ, tài khoản và danh sách ví là dữ liệu thật.
/// Xuất CSV giao dịch và gói toàn bộ dữ liệu cá nhân dùng API thật (BE Phase 91). Sao lưu tự động chưa có API nên vẫn khóa kèm "Sắp có".
class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({super.key});

  @override
  ConsumerState<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  _Range _range = _Range.month;
  bool _semicolon = true; // Excel đặt vùng Việt Nam tách cột bằng ';'
  bool _exporting = false;
  String? _accountId;

  String _rangeLabel(_Range r) => switch (r) {
        _Range.month => 'Tháng này',
        _Range.quarter => 'Quý này',
        _Range.year => 'Năm ${DateTime.now().year}',
      };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final pending = ref.watch(_pendingSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Xuất dữ liệu'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
      ),
      body: AmbientGlassBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _statusCard(context, email: user?.email ?? '', walletCount: accounts.length, pending: pending),
            const SizedBox(height: 16),
            _exportCard(context, accounts.map((a) => (id: a.id, name: a.name)).toList()),
            const SizedBox(height: 16),
            _personalDataCard(context),
          ],
        ),
      ),
    );
  }

  Widget _soon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: AppSpacing.roundedPill),
      child: Text('Sắp có', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateOn(context))),
    );
  }

  Widget _statusCard(BuildContext context, {required String email, required int walletCount, required AsyncValue<int> pending}) {
    final pendingCount = pending.valueOrNull;
    final synced = pendingCount == 0;
    final statusColor = pendingCount == null ? AppColors.textMuted(context) : (synced ? AppColors.safe : AppColors.warning);
    final statusText = pending.when(
      loading: () => 'ĐANG KIỂM TRA ĐỒNG BỘ',
      error: (_, __) => 'KHÔNG ĐỌC ĐƯỢC TRẠNG THÁI ĐỒNG BỘ',
      data: (n) => n == 0 ? 'ĐÃ ĐỒNG BỘ AN TOÀN' : '$n GIAO DỊCH CHỜ ĐỒNG BỘ',
    );
    return LiquidGlassCard(
      variant: LiquidGlassVariant.iridescentHero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(statusText, style: AppTypography.sectionLabel(context))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tài khoản', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                    Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ví đang theo dõi', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                  Text('$walletCount ví', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.inset(context, 0.7), borderRadius: AppSpacing.roundedPill),
            child: Row(
              children: [
                Icon(LucideIcons.history, size: 16, color: AppColors.textSecondary(context)),
                const SizedBox(width: 8),
                Expanded(child: Text('Chưa có bản sao lưu nào', style: AppTypography.caption(context).copyWith(fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('backup-now'),
            onPressed: null,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Sao lưu ngay bây giờ', maxLines: 1)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Flexible(child: Text('Tự động sao lưu hàng tuần', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14))),
                const SizedBox(width: 8),
                _soon(),
              ],
            ),
            subtitle: Text('Chỉ kích hoạt khi kết nối mạng Wi-Fi', style: AppTypography.caption(context).copyWith(fontSize: 12)),
            value: false,
            onChanged: null,
          ),
        ],
      ),
    );
  }

  Widget _exportCard(BuildContext context, List<({String id, String name})> accounts) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.download, size: 20, color: AppColors.textSecondary(context)),
              const SizedBox(width: 8),
              Expanded(child: Text('Xuất giao dịch (CSV)', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 14),
          Text('Khoảng thời gian giao dịch', style: AppTypography.caption(context).copyWith(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in _Range.values)
                ChoiceChip(
                  key: ValueKey('range-${r.name}'),
                  label: Text(_rangeLabel(r)),
                  selected: _range == r,
                  showCheckmark: false,
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _range == r ? AppColors.activeFg(context) : AppColors.textSecondary(context)),
                  selectedColor: AppColors.activeFill(context),
                  backgroundColor: AppColors.chipFill(context),
                  onSelected: (_) => setState(() => _range = r),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Phạm vi tài khoản & ví', style: AppTypography.caption(context).copyWith(fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            key: const ValueKey('export-accounts'),
            initialValue: _accountId,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.wallet, size: 18)),
            items: [
              DropdownMenuItem(value: null, child: Text('Tất cả tài khoản & ví (${accounts.length} tài khoản)')),
              for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            key: const ValueKey('export-semicolon'),
            contentPadding: EdgeInsets.zero,
            title: Text('Mở bằng Excel tiếng Việt', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('Tách cột bằng dấu ";" để Excel đặt vùng Việt Nam hiện đúng cột', style: AppTypography.caption(context).copyWith(fontSize: 12)),
            value: _semicolon,
            onChanged: (v) => setState(() => _semicolon = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('export-run'),
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.download, size: 18),
            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Xuất CSV và chia sẻ', maxLines: 1)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          ),
          const SizedBox(height: 8),
          Text(
            'Chỉ gồm giao dịch đã xác nhận. Tệp mở được bằng Excel hoặc Google Sheets.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _rangeDates() {
    final now = DateTime.now();
    return switch (_range) {
      _Range.month => (DateTime(now.year, now.month), now),
      _Range.quarter => (DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1), now),
      _Range.year => (DateTime(now.year), now),
    };
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final (from, to) = _rangeDates();
      final file = await ref
          .read(dataExportRepositoryProvider)
          .downloadTransactionsCsv(from: from, to: to, accountId: _accountId, semicolon: _semicolon);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], subject: 'Giao dịch FinMate');
    } catch (e) {
      _snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Gói toàn bộ dữ liệu cá nhân (quyền theo luật): xin mã email, nhập mã, máy chủ dựng gói nền, rồi tải ZIP.
  Widget _personalDataCard(BuildContext context) {
    final req = ref.watch(latestPersonalDataExportProvider).valueOrNull;
    final fmt = DateFormat('HH:mm dd/MM/yyyy');
    final String status = switch (req) {
      null => 'Bạn chưa yêu cầu gói dữ liệu nào.',
      final r when r.isWorking => 'Đang chuẩn bị gói dữ liệu. Bạn sẽ nhận thông báo khi xong.',
      final r when r.isReady => 'Gói dữ liệu đã sẵn sàng${r.expiresAt == null ? '' : ', tải được đến ${fmt.format(r.expiresAt!)}'}.',
      final r when r.status == 'Expired' => 'Gói lần trước đã hết hạn tải.',
      _ => 'Lần chuẩn bị trước không thành công, bạn có thể yêu cầu lại.',
    };
    return LiquidGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(LucideIcons.archive, size: 20, color: AppColors.textSecondary(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Tải toàn bộ dữ liệu cá nhân', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Một tệp ZIP chứa mọi dữ liệu FinMate lưu về bạn. Cần xác nhận bằng mã gửi tới email.',
            style: AppTypography.caption(context).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(status, key: const ValueKey('personal-data-status'), style: AppTypography.body(context).copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          if (req != null && req.isReady)
            FilledButton.icon(
              key: const ValueKey('personal-data-download'),
              onPressed: _exporting ? null : () => _downloadPackage(req.id),
              icon: const Icon(LucideIcons.download, size: 18),
              label: const Text('Tải gói dữ liệu'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
            )
          else
            OutlinedButton(
              key: const ValueKey('personal-data-request'),
              onPressed: _exporting || (req?.isWorking ?? false) ? null : _requestPackage,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
              child: const Text('Yêu cầu gói dữ liệu'),
            ),
        ],
      ),
    );
  }

  Future<void> _requestPackage() async {
    final repo = ref.read(dataExportRepositoryProvider);
    setState(() => _exporting = true);
    try {
      await repo.sendPersonalDataOtp();
      if (!mounted) return;
      final controller = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nhập mã xác nhận'),
          content: TextField(
            key: const ValueKey('personal-data-otp'),
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(helperText: 'Mã 6 số vừa gửi tới email của bạn, hết hạn sau 10 phút.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            TextButton(
              key: const ValueKey('personal-data-otp-submit'),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (code == null || code.isEmpty) return;
      await repo.requestPersonalData(code);
      _snack('Đã nhận yêu cầu. Bạn sẽ nhận thông báo khi gói dữ liệu sẵn sàng.');
      ref.invalidate(latestPersonalDataExportProvider);
    } catch (e) {
      _snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _downloadPackage(String id) async {
    setState(() => _exporting = true);
    try {
      final file = await ref.read(dataExportRepositoryProvider).downloadPersonalData(id);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/zip')], subject: 'Dữ liệu FinMate');
    } catch (e) {
      _snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
