import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/data/group_funds_repository.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/groups/presentation/screens/i7_settings_section.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// I7 — Cài đặt nhóm (Figma). Thông tin cơ bản (tên, mô tả, danh mục hoạt động, hiển thị giao dịch), cài đặt
/// quỹ/ngân sách và thông báo/phê duyệt qua `GET/PUT /groups/{id}/settings` (xem [GroupSettingsSection]).
/// Chưa làm: "Xuất sao kê Excel/PDF" (backend chưa có), ảnh nhóm (chưa có upload), "Giải tán nhóm & Chia số
/// dư" tự động (chỉ gọi `DELETE /groups/{id}`, lỗi `GROUP_FUND_NOT_SETTLED` nếu quỹ chưa tất toán).
///
/// Đây cũng là nơi duy nhất tạo quỹ chung (`POST /groups/{id}/funds`) — I3's hero card chỉ báo
/// "cần tạo quỹ trước (I7)" khi nhóm chưa có quỹ, nên hành động đó phải có thật ở đây, không thể để
/// dead-end.
class I7GroupSettingsScreen extends ConsumerWidget {
  final String groupId;
  const I7GroupSettingsScreen({super.key, required this.groupId});

  /// Trả về true khi [action] thành công.
  Future<bool> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      return false;
    }
  }

  void _refreshDetail(WidgetRef ref) {
    ref.invalidate(groupDetailProvider(groupId));
    ref.invalidate(groupActivitiesProvider(groupId));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, GroupEntity group) async {
    final controller = TextEditingController(text: group.name);
    final name = await GlassDialog.custom<String>(
      context,
      title: 'Đổi tên nhóm',
      contentBuilder: (ctx, setState) => TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tên nhóm')),
      actionsBuilder: (ctx, setState) => Row(
        children: [
          Expanded(child: GlassGhostButton(onPressed: () => Navigator.pop(ctx), label: 'Hủy')),
          const SizedBox(width: 12),
          Expanded(
            child: GlassPrimaryButton(
              label: 'Lưu',
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateGroup(id: groupId, name: name);
      _refreshDetail(ref);
    }, 'Đã đổi tên nhóm');
  }

  Future<void> _editDescription(BuildContext context, WidgetRef ref, GroupEntity group) async {
    final controller = TextEditingController(text: group.description ?? '');
    final text = await GlassDialog.custom<String>(
      context,
      title: 'Mô tả nhóm',
      contentBuilder: (ctx, setState) => TextField(
        key: const ValueKey('description-field'),
        controller: controller,
        maxLength: 200,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Mô tả (tối đa 200 ký tự)'),
      ),
      actionsBuilder: (ctx, setState) => Row(
        children: [
          Expanded(child: GlassGhostButton(onPressed: () => Navigator.pop(ctx), label: 'Hủy')),
          const SizedBox(width: 12),
          Expanded(child: GlassPrimaryButton(label: 'Lưu', onPressed: () => Navigator.pop(ctx, controller.text.trim()))),
        ],
      ),
    );
    if (text == null || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateGroup(id: groupId, description: text);
      _refreshDetail(ref);
    }, 'Đã cập nhật mô tả');
  }

  Future<void> _changeVisibility(BuildContext context, WidgetRef ref, GroupTransactionVisibility current) async {
    final picked = await GlassDialog.choice<GroupTransactionVisibility>(
      context,
      title: 'Chế độ hiển thị giao dịch',
      options: GroupTransactionVisibility.values,
      labelOf: (v) => v.label,
      isSelected: (v) => v == current,
    );
    if (picked == null || picked == current || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateGroup(id: groupId, transactionVisibility: picked);
      _refreshDetail(ref);
    }, 'Đã đổi chế độ hiển thị');
  }

  Future<bool> _toggleAlerts(BuildContext context, WidgetRef ref, bool enabled) {
    return _runAction(
      context,
      ref,
      () => ref.read(groupsRepositoryProvider).setAlerts(groupId: groupId, enabled: enabled),
      enabled ? 'Đã bật cảnh báo' : 'Đã tắt cảnh báo',
    );
  }

  Future<void> _createFund(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: 'Quỹ chung');
    final noteController = TextEditingController();
    final confirmed = await GlassDialog.custom<bool>(
      context,
      title: 'Tạo quỹ chung',
      contentBuilder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('create-fund-name'),
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Tên quỹ'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('create-fund-note'),
            controller: noteController,
            decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
          ),
        ],
      ),
      actionsBuilder: (ctx, setState) => Row(
        children: [
          Expanded(child: GlassGhostButton(onPressed: () => Navigator.pop(ctx, false), label: 'Hủy')),
          const SizedBox(width: 12),
          Expanded(child: GlassPrimaryButton(label: 'Tạo quỹ', onPressed: () => Navigator.pop(ctx, true))),
        ],
      ),
    );
    if (confirmed != true || nameController.text.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupFundsRepositoryProvider).createFund(
            groupId: groupId,
            name: nameController.text.trim(),
            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          );
      ref.invalidate(groupFundsProvider(groupId));
      ref.invalidate(groupPrimaryFundProvider(groupId));
      ref.read(groupsControllerProvider.notifier).load(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo quỹ chung')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Rời nhóm',
      message: 'Rời nhóm "$name"? Bạn sẽ cần được mời lại nếu muốn tham gia lần sau.',
      confirmLabel: 'Rời nhóm',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsControllerProvider.notifier).leave(groupId);
      if (context.mounted) {
        context.pop();
        context.pop();
      }
      messenger.showSnackBar(const SnackBar(content: Text('Đã rời nhóm')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _dissolve(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Giải tán nhóm',
      message: 'Giải tán nhóm "$name"? Toàn bộ dữ liệu chia sẻ trong nhóm sẽ mất, không thể hoàn tác.',
      confirmLabel: 'Giải tán',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsControllerProvider.notifier).delete(groupId);
      if (context.mounted) {
        context.pop();
        context.pop();
      }
      messenger.showSnackBar(const SnackBar(content: Text('Đã giải tán nhóm')));
    } catch (e) {
      final isFundNotSettled = e is ApiException && e.code == 'GROUP_FUND_NOT_SETTLED';
      messenger.showSnackBar(SnackBar(
        content: Text(
          isFundNotSettled
              ? 'Quỹ chung của nhóm chưa về 0 — rút hết hoặc chi hết số dư ở tab "Quỹ chung" rồi thử giải tán lại.'
              : errorMessage(e),
        ),
        backgroundColor: GlassColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final fundAsync = ref.watch(groupPrimaryFundProvider(groupId));

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Cài đặt nhóm', style: GlassTypography.headlineSm()),
        ),
        body: SafeArea(
          child: groupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger))),
            data: (group) {
              final canManageFunds = group.isOwner || group.myPermissions.contains(GroupPermission.manageFunds);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text('THÔNG TIN CƠ BẢN', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          ListTile(
                            key: const ValueKey('rename-group'),
                            leading: const Icon(LucideIcons.users2, size: 20),
                            title: const Text('Tên nhóm'),
                            subtitle: Text(group.name),
                            trailing: group.isOwner ? const Icon(LucideIcons.pencil, size: 18) : null,
                            onTap: group.isOwner ? () => _rename(context, ref, group) : null,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            key: const ValueKey('group-description'),
                            leading: const Icon(LucideIcons.fileText, size: 20),
                            title: const Text('Mô tả nhóm'),
                            subtitle: Text(group.description == null || group.description!.isEmpty ? 'Chưa có mô tả' : group.description!),
                            trailing: group.isOwner ? const Icon(LucideIcons.pencil, size: 18) : null,
                            onTap: group.isOwner ? () => _editDescription(context, ref, group) : null,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            key: const ValueKey('group-type-row'),
                            leading: const Icon(LucideIcons.layoutGrid, size: 20),
                            title: const Text('Danh mục hoạt động'),
                            subtitle: Text(group.type.label),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            key: const ValueKey('change-visibility'),
                            leading: const Icon(LucideIcons.eye, size: 20),
                            title: const Text('Hiển thị giao dịch'),
                            subtitle: Text(group.transactionVisibility.label),
                            trailing: group.isOwner ? const Icon(LucideIcons.chevronRight, size: 18) : null,
                            onTap: group.isOwner ? () => _changeVisibility(context, ref, group.transactionVisibility) : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('QUỸ CHUNG', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: fundAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger)),
                      data: (fund) => fund != null
                          ? Row(
                              children: [
                                Icon(LucideIcons.wallet, size: 20, color: GlassColors.accentSkyBlue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(fund.name, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                                      Text(fund.formattedBalance, style: GlassTypography.bodySm()),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nhóm chưa có quỹ chung nào.', style: GlassTypography.bodyMd()),
                                const SizedBox(height: 4),
                                Text(
                                  'Tạo quỹ chung để dùng nút "Nạp quỹ nhóm"/"Ghi khoản chi" ở trang chi tiết nhóm.',
                                  style: GlassTypography.bodySm(color: GlassColors.textMuted),
                                ),
                                const SizedBox(height: 12),
                                if (canManageFunds)
                                  AsyncActionBuilder(
                                    onPressed: () => _createFund(context, ref),
                                    builder: (_, onTap, running) => OutlinedButton.icon(
                                      key: const ValueKey('create-fund'),
                                      onPressed: onTap,
                                      icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.plusCircle, size: 16),
                                      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Tạo quỹ chung', maxLines: 1)),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  GroupSettingsSection(groupId: groupId, canEdit: group.isOwner),
                  const SizedBox(height: 20),
                  Text('CẢNH BÁO', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: _AlertToggle(initial: ref.watch(groupSettingsProvider(groupId)).valueOrNull?.alertsEnabled, onChange: (enabled) => _toggleAlerts(context, ref, enabled)),
                  ),
                  const SizedBox(height: 20),
                  Text('VÙNG QUẢN TRỊ NÂNG CAO', style: GlassTypography.labelCaps(color: GlassColors.danger)),
                  const SizedBox(height: 8),
                  if (group.isOwner) ...[
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          key: const ValueKey('go-transfer-ownership'),
                          leading: const Icon(LucideIcons.userCog, size: 20),
                          title: const Text('Chuyển giao vai trò Trưởng nhóm'),
                          trailing: const Icon(LucideIcons.chevronRight, size: 18),
                          onTap: () => context.push('/group-members', extra: groupId),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: AsyncActionBuilder(
                        onPressed: () => _dissolve(context, ref, group.name),
                        builder: (_, onTap, running) => OutlinedButton.icon(
                          key: const ValueKey('dissolve-group'),
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GlassColors.danger,
                            side: BorderSide(color: GlassColors.danger),
                            shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                          ),
                          icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.trash2, size: 16),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Giải tán nhóm', maxLines: 1)),
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: AsyncActionBuilder(
                        onPressed: () => _leave(context, ref, group.name),
                        builder: (_, onTap, running) => OutlinedButton.icon(
                          key: const ValueKey('leave-group'),
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GlassColors.danger,
                            side: BorderSide(color: GlassColors.danger),
                            shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                          ),
                          icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.logOut, size: 16),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Rời khỏi nhóm', maxLines: 1)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Hai nút Bật/Tắt cảnh báo: nút vừa bấm thành công sẽ sáng (active). BE chỉ có PUT, không trả trạng
/// thái hiện tại, nên chưa bấm lần nào thì chưa nút nào sáng — không đoán trạng thái.
class _AlertToggle extends StatefulWidget {
  final Future<bool> Function(bool enabled) onChange;
  final bool? initial;
  const _AlertToggle({required this.onChange, this.initial});

  @override
  State<_AlertToggle> createState() => _AlertToggleState();
}

class _AlertToggleState extends State<_AlertToggle> {
  bool? _on;
  bool _busy = false;

  Future<void> _set(bool enabled) async {
    if (_busy || (_on ?? widget.initial) == enabled) return;
    setState(() => _busy = true);
    final ok = await widget.onChange(enabled);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _on = enabled;
    });
  }

  Widget _button({required Key key, required bool enabled, required IconData icon, required String label}) {
    final active = (_on ?? widget.initial) == enabled;
    return Expanded(
      child: Semantics(
        selected: active,
        child: AsyncActionBuilder(
          onPressed: _busy ? null : () => _set(enabled),
          builder: (_, onTap, running) => OutlinedButton.icon(
            key: key,
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: active ? GlassColors.ink : null,
              foregroundColor: active ? GlassColors.onInk : null,
              side: active ? BorderSide(color: GlassColors.ink) : null,
            ),
            icon: running ? const ButtonLoadingIndicator(size: 16) : Icon(icon, size: 16),
            // Một dòng, tự thu nhỏ chữ khi hẹp thay vì xuống hàng.
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _button(key: const ValueKey('toggle-alerts-on'), enabled: true, icon: LucideIcons.bellRing, label: 'Bật cảnh báo'),
      const SizedBox(width: 8),
      _button(key: const ValueKey('toggle-alerts-off'), enabled: false, icon: LucideIcons.bellOff, label: 'Tắt cảnh báo'),
    ],
  );
}
