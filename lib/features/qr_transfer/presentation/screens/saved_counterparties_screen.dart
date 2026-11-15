import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/qr_transfer/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';
import 'package:finmate/features/qr_transfer/presentation/controllers/qr_providers.dart';

/// Màn C4: người nhận VietQR FinMate đã nhớ (kèm danh mục), lấy từ `/api/v1/qr/counterparties`.
class SavedCounterpartiesScreen extends ConsumerWidget {
  const SavedCounterpartiesScreen({super.key});

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editCategory(BuildContext context, WidgetRef ref, CounterpartyOverride item) async {
    final List<Category> categories;
    try {
      categories = await ref.read(categoriesProvider.future);
    } on Object catch (e) {
      if (context.mounted) _toast(context, errorMessage(e));
      return;
    }
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Đổi danh mục cho ${item.displayName ?? item.accountNumber}', style: AppTypography.h3(sheet)),
              ),
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
      if (context.mounted) _toast(context, 'Đã cập nhật danh mục người nhận.');
    } on Object catch (e) {
      if (context.mounted) _toast(context, errorMessage(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CounterpartyOverride item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Bỏ người nhận đã lưu?'),
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
      if (context.mounted) _toast(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(qrOverridesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Người nhận đã lưu'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(qrOverridesProvider.future),
          child: overrides.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              text: errorMessage(e),
              actionLabel: 'Thử lại',
              onAction: () => ref.invalidate(qrOverridesProvider),
            ),
            data: (items) => items.isEmpty
                ? const _Message(
                    text: 'Chưa có người nhận nào. FinMate lưu người nhận khi bạn chọn danh mục lúc quét mã QR chuyển khoản.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                    children: [
                      Text('DANH SÁCH TÀI KHOẢN VIETQR THƯỜNG DÙNG', style: AppTypography.sectionLabel(context)),
                      const SizedBox(height: 12),
                      for (final r in items) _tile(context, ref, r),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, CounterpartyOverride r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push(
          '/qr-transfer',
          extra: VietQrData(bankBin: r.bankBin, accountNumber: r.accountNumber, beneficiaryName: r.displayName),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(LucideIcons.send, size: 20, color: AppColors.primaryAction(context))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.displayName ?? r.accountNumber,
                    style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.bankName} • ${r.categoryName}',
                    style: AppTypography.caption(context).copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.accountNumber,
                    style: AppTypography.tabular(
                      AppTypography.caption(context).copyWith(color: AppColors.textMuted(context), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 16),
              tooltip: 'Đổi danh mục',
              onPressed: () => _editCategory(context, ref, r),
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 16),
              tooltip: 'Bỏ người nhận đã lưu',
              onPressed: () => _delete(context, ref, r),
            ),
          ],
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
    // Cuộn được để kéo-làm-mới hoạt động cả khi rỗng/lỗi.
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
