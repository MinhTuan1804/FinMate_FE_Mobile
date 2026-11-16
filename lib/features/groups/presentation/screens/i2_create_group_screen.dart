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
  GroupType _type = GroupType.family;
  String? _nameError;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
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
      final created = await ref.read(groupsControllerProvider.notifier).create(name: name, type: _type);
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loại hình nhóm', style: GlassTypography.headlineSm()),
                    const SizedBox(height: 12),
                    ...GroupType.values.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TypeOption(
                            type: t,
                            selected: _type == t,
                            onTap: () => setState(() => _type = t),
                          ),
                        )),
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

class _TypeOption extends StatelessWidget {
  final GroupType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = groupTypeColor(type);
    return InkWell(
      key: ValueKey('group-type-${type.apiValue}'),
      onTap: onTap,
      borderRadius: GlassRadius.roundedCard,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : GlassColors.secondarySurface,
          borderRadius: GlassRadius.roundedCard,
          border: Border.all(color: selected ? color : GlassColors.glassBorder, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(groupTypeIcon(type), color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(type.label, style: GlassTypography.bodyMd())),
            Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 18,
              color: selected ? color : GlassColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
