import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/groups/presentation/group_type_icons.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// I2 — Tạo nhóm tài chính mới (Stitch `i2_create_group`). Bỏ khối "Biểu tượng & diện mạo" (không có
/// trường icon trên BE), "Loại quỹ & phương thức chia tiền" (BỎ split-bill, xem quyết định phạm vi
/// Luồng 8a), "Đơn vị tiền tệ"/"Quy tắc quản trị nhóm" (không có trên BE) — chỉ còn đúng 2 trường
/// `POST /groups` thật sự nhận: tên + loại nhóm. Nút "Tiếp tục: Mời thành viên" đổi thành "Tạo nhóm",
/// tạo xong vào thẳng I3 (chi tiết nhóm, có nút mời thành viên riêng) thay vì dựng màn I5 ở đợt này.
class I2CreateGroupScreen extends ConsumerStatefulWidget {
  const I2CreateGroupScreen({super.key});

  @override
  ConsumerState<I2CreateGroupScreen> createState() => _I2CreateGroupScreenState();
}

class _I2CreateGroupScreenState extends ConsumerState<I2CreateGroupScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  GroupType _type = GroupType.family;

  /// Khóa biểu tượng đã chọn; null = theo loại nhóm.
  String? _icon;
  String _settlementModel = 'SharedFund';
  String? _nameError;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Vui lòng nhập tên nhóm');
      return;
    }
    setState(() {
      _nameError = null;
      _submitting = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(groupsControllerProvider.notifier).create(
            name: name,
            type: _type,
            icon: _icon,
            description: _description.text.trim(),
            settlementModel: _settlementModel,
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo nhóm')));
      context.pushReplacement('/group-detail', extra: created.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const ValueKey('close-create-group'),
            icon: Icon(LucideIcons.x, color: GlassColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text('Tạo nhóm tài chính mới', style: GlassTypography.headlineSm()),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    Text('BIỂU TƯỢNG & DIỆN MẠO', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                    const SizedBox(height: 12),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: groupTypeColor(_type).withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Icon(groupIconFor(_icon, _type), size: 30, color: groupTypeColor(_type)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final entry in groupIconChoices.entries)
                          Semantics(
                            button: true,
                            selected: _icon == entry.key,
                            label: 'Biểu tượng ${entry.key}',
                            child: InkWell(
                              key: ValueKey('group-icon-${entry.key}'),
                              customBorder: const CircleBorder(),
                              onTap: () => setState(() => _icon = entry.key),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _icon == entry.key ? GlassColors.ink : GlassColors.secondarySurface,
                                ),
                                child: Icon(entry.value, size: 20, color: _icon == entry.key ? GlassColors.onInk : GlassColors.textSecondary),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tên nhóm tài chính', style: GlassTypography.headlineSm()),
                        Text('BẮT BUỘC', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('group-name-field'),
                      controller: _name,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Tổ ấm nhỏ, Quỹ phòng trọ',
                        errorText: _nameError,
                      ),
                      onChanged: (_) {
                        if (_nameError != null) setState(() => _nameError = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('group-description-field'),
                      controller: _description,
                      maxLength: 200,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Mô tả ngắn (không bắt buộc)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Loại hình nhóm', style: GlassTypography.headlineSm()),
                        Text('Chọn 1 loại', style: GlassTypography.bodySm()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Hàng chip cuộn ngang như Figma; chọn 1 loại.
                    SizedBox(
                      height: 44,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final t in GroupType.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _TypeOption(type: t, selected: _type == t, onTap: () => setState(() => _type = t)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loại quỹ & phương thức chia tiền', style: GlassTypography.headlineSm()),
                    const SizedBox(height: 12),
                    _ModelOption(
                      key: const ValueKey('settlement-SharedFund'),
                      title: 'Quỹ chung đóng góp',
                      subtitle: 'Mọi người cùng nộp tiền vào quỹ, chi tiêu trừ thẳng từ quỹ.',
                      selected: _settlementModel == 'SharedFund',
                      onTap: () => setState(() => _settlementModel = 'SharedFund'),
                    ),
                    const SizedBox(height: 8),
                    _ModelOption(
                      key: const ValueKey('settlement-SplitBill'),
                      title: 'Chia đều từng khoản chi (Split bill)',
                      subtitle: 'Ai trả trước thì app tính phần mỗi người nợ và gợi ý cách trả tối giản.',
                      selected: _settlementModel == 'SplitBill',
                      onTap: () => setState(() => _settlementModel = 'SplitBill'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                key: const ValueKey('currency-card'),
                child: Row(
                  children: [
                    Icon(LucideIcons.banknote, size: 20, color: GlassColors.accentSkyBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đơn vị tiền tệ', style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                          Text('Quy chuẩn hiển thị toàn nhóm', style: GlassTypography.bodySm()),
                        ],
                      ),
                    ),
                    Text('VND (₫)', style: GlassTypography.labelNumeric()),
                    const SizedBox(width: 6),
                    Icon(LucideIcons.lock, size: 14, color: GlassColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('submit-create-group'),
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassColors.ink,
                    foregroundColor: GlassColors.onInk,
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                  ),
                  child: _submitting
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlassColors.onInk))
                      : Text('Tạo nhóm', style: GlassTypography.buttonText()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ModelOption({super.key, required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: GlassRadius.roundedCard,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? GlassColors.accentSkyBlue.withValues(alpha: 0.12) : GlassColors.secondarySurface,
            borderRadius: GlassRadius.roundedCard,
            border: Border.all(color: selected ? GlassColors.accentSkyBlue : GlassColors.glassBorder, width: selected ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(selected ? LucideIcons.circleDot : LucideIcons.circle, size: 18, color: selected ? GlassColors.ink : GlassColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GlassTypography.bodySm(color: GlassColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final GroupType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? GlassColors.onInk : GlassColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('group-type-${type.apiValue}'),
        onTap: onTap,
        borderRadius: GlassRadius.roundedPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? GlassColors.ink : GlassColors.secondarySurface,
            borderRadius: GlassRadius.roundedPill,
            border: Border.all(color: selected ? GlassColors.ink : GlassColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(groupTypeIcon(type), size: 16, color: fg),
              const SizedBox(width: 6),
              Text(type.label, style: GlassTypography.bodyMd(color: fg).copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
