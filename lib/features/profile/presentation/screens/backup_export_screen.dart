import 'package:flutter/material.dart';
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

enum _Format { xlsx, pdf, csv, json }

extension on _Format {
  String get label => switch (this) {
        _Format.xlsx => 'Excel (.xlsx)',
        _Format.pdf => 'PDF (.pdf)',
        _Format.csv => 'CSV (.csv)',
        _Format.json => 'JSON (.json)',
      };

  IconData get icon => switch (this) {
        _Format.xlsx => LucideIcons.sheet,
        _Format.pdf => LucideIcons.fileText,
        _Format.csv => LucideIcons.fileSpreadsheet,
        _Format.json => LucideIcons.fileJson,
      };

  String get short => switch (this) {
        _Format.xlsx => 'Excel',
        _Format.pdf => 'PDF',
        _Format.csv => 'CSV',
        _Format.json => 'JSON',
      };
}

/// Màn H5: Sao lưu & Xuất dữ liệu (theo Figma). Phần trạng thái đồng bộ, tài khoản và danh sách ví là dữ liệu thật.
/// BE chưa có API sao lưu và xuất tệp (`me/exports`), nên các lựa chọn xuất chỉ để chọn, còn nút thực hiện bị khóa kèm nhãn "Sắp có";
/// không giả lập kết quả thành công như bản trước.
class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({super.key});

  @override
  ConsumerState<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  _Range _range = _Range.month;
  _Format _format = _Format.xlsx;
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
          ],
        ),
      ),
    );
  }

  Widget _soon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: AppSpacing.roundedPill),
      child: Text('Sắp có', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slateOn(context))),
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
                Expanded(child: Text('Chưa có bản sao lưu nào', style: AppTypography.caption(context).copyWith(fontSize: 12.5))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('backup-now'),
            onPressed: null,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Sao lưu ngay bây giờ'),
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
              Expanded(child: Text('Tùy chọn xuất dữ liệu', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700))),
              _soon(),
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
          Text('Định dạng tệp xuất', style: AppTypography.caption(context).copyWith(fontSize: 12)),
          const SizedBox(height: 8),
          for (final f in _Format.values) _formatTile(context, f),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(LucideIcons.lock, size: 18, color: AppColors.textSecondary(context)),
            title: Row(
              children: [
                Flexible(child: Text('Mã hóa tệp bằng mật khẩu', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14))),
                const SizedBox(width: 8),
                _soon(),
              ],
            ),
            value: false,
            onChanged: null,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('export-run'),
            onPressed: null,
            icon: const Icon(LucideIcons.download, size: 18),
            label: Text('Xuất và tải về (${_format.short})'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          ),
          const SizedBox(height: 8),
          Text(
            'Xuất tệp cần máy chủ hỗ trợ nên chưa dùng được. Dữ liệu của bạn vẫn an toàn trên tài khoản FinMate.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _formatTile(BuildContext context, _Format f) {
    final selected = _format == f;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Định dạng ${f.label}',
        child: InkWell(
          key: ValueKey('format-${f.name}'),
          borderRadius: AppSpacing.roundedLarge,
          onTap: () => setState(() => _format = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.inset(context, 0.6),
              borderRadius: AppSpacing.roundedLarge,
              border: Border.all(color: selected ? AppColors.textPrimary(context) : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Icon(f.icon, size: 22, color: AppColors.textSecondary(context)),
                const SizedBox(width: 14),
                Expanded(child: Text(f.label, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15))),
                Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, size: 22, color: selected ? AppColors.textPrimary(context) : AppColors.textMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
