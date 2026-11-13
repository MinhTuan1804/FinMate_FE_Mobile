import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';
import 'package:finmate/features/qr_transfers/presentation/controllers/qr_transfer_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

String _maskAccount(String account) => account.length <= 4 ? account : '•${account.substring(account.length - 4)}';

/// C5 — Sửa người nhận đã lưu. Chỉ sửa được danh mục mặc định ([updateCounterparty] — API chỉ
/// nhận categoryId) và xóa khỏi danh bạ. Ngân hàng/số tài khoản/tên hiển thị chỉ đọc, vì chúng
/// do lần quét QR đầu tiên ghi lại, không có endpoint sửa.
class C5EditBeneficiaryScreen extends ConsumerStatefulWidget {
  final CounterpartyOverrideEntity counterparty;

  const C5EditBeneficiaryScreen({super.key, required this.counterparty});

  @override
  ConsumerState<C5EditBeneficiaryScreen> createState() => _C5EditBeneficiaryScreenState();
}

class _C5EditBeneficiaryScreenState extends ConsumerState<C5EditBeneficiaryScreen> {
  late String _categoryId = widget.counterparty.categoryId;
  bool _saving = false;
  bool _deleting = false;

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(counterpartyOverridesControllerProvider.notifier).update(widget.counterparty.id, _categoryId);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi.')));
      context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa người nhận khỏi danh bạ?'),
        content: const Text('Lần quét sau với người nhận này sẽ hỏi lại danh mục như chưa từng lưu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Xóa', style: TextStyle(color: GlassColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(counterpartyOverridesControllerProvider.notifier).delete(widget.counterparty.id);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counterparty = widget.counterparty;
    final categoriesAsync = ref.watch(categoriesProvider);
    final name = counterparty.displayName ?? counterparty.accountNumber;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Thông tin người nhận', style: GlassTypography.headlineMd()),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              GlassCard(
                level: 2,
                borderRadius: GlassRadius.roundedCardLarge,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: GlassColors.secondarySurface,
                      child: Text(
                        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                        style: GlassTypography.headlineLg(color: GlassColors.slateAnchor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: GlassTypography.headlineMd(), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(counterparty.bankName, style: GlassTypography.bodySm()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                borderRadius: GlassRadius.roundedCardLarge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHI TIẾT THỤ HƯỞNG', style: GlassTypography.labelCaps()),
                    const SizedBox(height: 12),
                    _readOnlyField(label: 'NGÂN HÀNG THỤ HƯỞNG', value: counterparty.bankName, icon: LucideIcons.building2),
                    const SizedBox(height: 10),
                    _readOnlyField(label: 'SỐ TÀI KHOẢN', value: _maskAccount(counterparty.accountNumber), icon: LucideIcons.creditCard),
                    if (counterparty.displayName != null) ...[
                      const SizedBox(height: 10),
                      _readOnlyField(label: 'TÊN NGƯỜI NHẬN', value: counterparty.displayName!, icon: LucideIcons.user),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                borderRadius: GlassRadius.roundedCardLarge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DANH MỤC CHI TIÊU MẶC ĐỊNH', style: GlassTypography.labelCaps()),
                    const SizedBox(height: 12),
                    categoriesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                      data: (categories) => DropdownButtonFormField<String>(
                        key: const ValueKey('c5-category'),
                        initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.55),
                          border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none),
                        ),
                        items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                        onChanged: (v) {
                          if (v != null) setState(() => _categoryId = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassPrimaryButton(
                key: const ValueKey('c5-save'),
                label: 'Lưu thay đổi',
                icon: LucideIcons.save,
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const ValueKey('c5-delete'),
                  onPressed: _deleting ? null : _delete,
                  icon: Icon(LucideIcons.trash2, size: 18, color: GlassColors.danger),
                  label: Text(
                    _deleting ? 'Đang xóa...' : 'Xóa người nhận khỏi danh bạ',
                    style: TextStyle(color: GlassColors.danger, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GlassColors.danger.withValues(alpha: 0.4)),
                    shape: const RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField({required String label, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GlassTypography.labelCaps()),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: GlassRadius.roundedInput,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: GlassColors.textMuted),
              const SizedBox(width: 8),
              Expanded(child: Text(value, style: GlassTypography.bodyMd(color: GlassColors.textPrimary))),
            ],
          ),
        ),
      ],
    );
  }
}
