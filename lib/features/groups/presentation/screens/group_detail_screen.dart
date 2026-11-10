import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';

/// Chi tiết một nhóm: thông tin, danh sách thành viên, nhật ký hoạt động.
/// Đơn giản để test nhanh toàn bộ API groups còn thiếu ở FE.
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  Future<void> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  void _refreshDetail(WidgetRef ref) {
    ref.invalidate(groupDetailProvider(groupId));
    ref.invalidate(groupMembersProvider(groupId));
    ref.invalidate(groupActivitiesProvider(groupId));
    ref.invalidate(groupInvitationsProvider(groupId));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, GroupEntity group) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tên nhóm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateGroup(id: groupId, name: name);
      _refreshDetail(ref);
    }, 'Đã đổi tên nhóm');
  }

  Future<void> _changeVisibility(BuildContext context, WidgetRef ref, GroupTransactionVisibility current) async {
    final picked = await showDialog<GroupTransactionVisibility>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chế độ hiển thị giao dịch'),
        children: GroupTransactionVisibility.values
            .map((v) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, v),
                  child: Row(children: [
                    if (v == current) const Icon(LucideIcons.check, size: 16) else const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(v.label),
                  ]),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == current || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateGroup(id: groupId, transactionVisibility: picked);
      _refreshDetail(ref);
    }, 'Đã đổi chế độ hiển thị');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhóm'),
        content: Text('Xóa nhóm "$name"? Toàn bộ dữ liệu chia sẻ trong nhóm sẽ mất, không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsControllerProvider.notifier).delete(groupId);
      if (context.mounted) context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa nhóm')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời nhóm'),
        content: Text('Rời nhóm "$name"? Bạn sẽ cần được mời lại nếu muốn tham gia lần sau.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Rời nhóm', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsControllerProvider.notifier).leave(groupId);
      if (context.mounted) context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Đã rời nhóm')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _toggleAlerts(BuildContext context, WidgetRef ref, bool enabled) async {
    await _runAction(
      context,
      ref,
      () => ref.read(groupsRepositoryProvider).setAlerts(groupId: groupId, enabled: enabled),
      enabled ? 'Đã bật cảnh báo' : 'Đã tắt cảnh báo',
    );
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, GroupMemberEntity member) async {
    final picked = await showDialog<GroupRole>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Đổi vai trò của ${member.displayName}'),
        children: GroupRole.values
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r),
                  child: Row(children: [
                    if (r == member.role) const Icon(LucideIcons.check, size: 16) else const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(r.label),
                  ]),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == member.role || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).updateMember(groupId: groupId, userId: member.userId, role: picked);
      ref.invalidate(groupMembersProvider(groupId));
    }, 'Đã đổi vai trò');
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, GroupMemberEntity member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: Text('Xóa ${member.displayName} khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).removeMember(groupId: groupId, userId: member.userId);
      ref.invalidate(groupMembersProvider(groupId));
    }, 'Đã xóa thành viên');
  }

  Future<void> _transferOwnership(BuildContext context, WidgetRef ref, List<GroupMemberEntity> members, String myUserId) async {
    final candidates = members.where((m) => m.userId != myUserId).toList();
    if (candidates.isEmpty) return;
    final picked = await showDialog<GroupMemberEntity>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chuyển quyền chủ nhóm cho'),
        children: candidates
            .map((m) => SimpleDialogOption(onPressed: () => Navigator.pop(context, m), child: Text(m.displayName)))
            .toList(),
      ),
    );
    if (picked == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận chuyển quyền chủ nhóm'),
        content: Text('Chuyển quyền chủ nhóm cho ${picked.displayName}? Bạn sẽ trở thành quản lý.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chuyển')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).transferOwnership(groupId: groupId, newOwnerUserId: picked.userId);
      _refreshDetail(ref);
    }, 'Đã chuyển quyền chủ nhóm');
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_InviteInput>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(groupsRepositoryProvider).createInvitation(
            groupId: groupId,
            email: result.email,
            role: result.role,
          );
      ref.invalidate(groupInvitationsProvider(groupId));
      if (created.token != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Mã lời mời'),
            content: SelectableText(created.token!),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
          ),
        );
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Đã tạo lời mời, email sẽ được gửi')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _revokeInvitation(BuildContext context, WidgetRef ref, GroupInvitationEntity invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy lời mời'),
        content: Text('Hủy lời mời ${invitation.email ?? "qua link"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hủy lời mời', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () async {
      await ref.read(groupsRepositoryProvider).revokeInvitation(groupId: groupId, invitationId: invitation.id);
      ref.invalidate(groupInvitationsProvider(groupId));
    }, 'Đã hủy lời mời');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final activitiesAsync = ref.watch(groupActivitiesProvider(groupId));
    final invitationsAsync = ref.watch(groupInvitationsProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: Text(groupAsync.valueOrNull?.name ?? 'Chi tiết nhóm')),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(errorMessage(e), style: AppTypography.body(context))),
        data: (group) {
          final members = membersAsync.valueOrNull ?? const [];
          return RefreshIndicator(
            onRefresh: () async => _refreshDetail(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(group: group, onRename: group.isOwner ? () => _rename(context, ref, group) : null,
                    onChangeVisibility: group.isOwner ? () => _changeVisibility(context, ref, group.transactionVisibility) : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('toggle-alerts-on'),
                        onPressed: () => _toggleAlerts(context, ref, true),
                        icon: const Icon(LucideIcons.bellRing, size: 16),
                        label: const Text('Bật cảnh báo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('toggle-alerts-off'),
                        onPressed: () => _toggleAlerts(context, ref, false),
                        icon: const Icon(LucideIcons.bellOff, size: 16),
                        label: const Text('Tắt cảnh báo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('open-group-finance'),
                  onPressed: () => context.push('/group-finance', extra: groupId),
                  icon: const Icon(LucideIcons.receipt, size: 16),
                  label: const Text('Tài chính nhóm'),
                ),
                const SizedBox(height: 20),
                Text('Thành viên (${members.length})', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...members.map((m) => _MemberTile(
                      member: m,
                      canManage: group.isOwner,
                      onChangeRole: () => _changeRole(context, ref, m),
                      onRemove: () => _removeMember(context, ref, m),
                    )),
                if (group.isOwner) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('transfer-ownership'),
                    onPressed: () => _transferOwnership(context, ref, members, ref.read(currentUserIdProvider) ?? ''),
                    icon: const Icon(LucideIcons.users, size: 16),
                    label: const Text('Chuyển quyền chủ nhóm'),
                  ),
                ],
                if (group.isOwner) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Lời mời đang chờ', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        key: const ValueKey('invite-member'),
                        tooltip: 'Mời thành viên',
                        icon: const Icon(LucideIcons.plus, size: 18),
                        onPressed: () => _invite(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  invitationsAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                    error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
                    data: (invitations) {
                      if (invitations.isEmpty) {
                        return Text('Chưa có lời mời nào đang chờ.', style: AppTypography.caption(context));
                      }
                      return Column(
                        children: invitations
                            .map((inv) => _InvitationTile(invitation: inv, onRevoke: () => _revokeInvitation(context, ref, inv)))
                            .toList(),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),
                Text('Hoạt động gần đây', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                activitiesAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                  error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context)),
                  data: (activities) {
                    if (activities.isEmpty) {
                      return Text('Chưa có hoạt động nào.', style: AppTypography.caption(context));
                    }
                    return Column(
                      children: activities
                          .map((a) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(LucideIcons.info, size: 18),
                                title: Text(a.type.label),
                                subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(a.createdAt.toLocal())),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (group.isOwner)
                  OutlinedButton.icon(
                    key: const ValueKey('delete-group'),
                    onPressed: () => _delete(context, ref, group.name),
                    icon: Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                    label: Text('Xóa nhóm', style: TextStyle(color: AppColors.danger)),
                  )
                else
                  OutlinedButton.icon(
                    key: const ValueKey('leave-group'),
                    onPressed: () => _leave(context, ref, group.name),
                    icon: Icon(LucideIcons.logOut, size: 16, color: AppColors.danger),
                    label: Text('Rời nhóm', style: TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final GroupEntity group;
  final VoidCallback? onRename;
  final VoidCallback? onChangeVisibility;
  const _InfoCard({required this.group, this.onRename, this.onChangeVisibility});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
              Expanded(
                child: Text(group.name, style: AppTypography.h3(context)),
              ),
              if (onRename != null)
                IconButton(key: const ValueKey('rename-group'), tooltip: 'Đổi tên', icon: const Icon(LucideIcons.pencil, size: 18), onPressed: onRename),
            ],
          ),
          const SizedBox(height: 4),
          Text('${group.type.label} · Vai trò của bạn: ${group.myRole.label}', style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          InkWell(
            onTap: onChangeVisibility,
            child: Row(
              children: [
                Text('Hiển thị giao dịch: ${group.transactionVisibility.label}', style: AppTypography.caption(context)),
                if (onChangeVisibility != null) ...[
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.pencil, size: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMemberEntity member;
  final bool canManage;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;
  const _MemberTile({required this.member, required this.canManage, required this.onChangeRole, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('member-${member.userId}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(LucideIcons.user, size: 20),
      title: Text(member.displayName),
      subtitle: Text(member.role.label),
      trailing: canManage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('change-role-${member.userId}'),
                  tooltip: 'Đổi vai trò',
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  onPressed: onChangeRole,
                ),
                IconButton(
                  key: ValueKey('remove-member-${member.userId}'),
                  tooltip: 'Xóa',
                  icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                  onPressed: onRemove,
                ),
              ],
            )
          : null,
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final GroupInvitationEntity invitation;
  final VoidCallback onRevoke;
  const _InvitationTile({required this.invitation, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('invitation-${invitation.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(LucideIcons.mail, size: 20),
      title: Text(invitation.email ?? 'Mời qua link'),
      subtitle: Text(
        '${invitation.role.label} · Hết hạn ${DateFormat('dd/MM/yyyy').format(invitation.expiresAt.toLocal())}'
        '${invitation.emailSent == false ? " · Gửi email thất bại" : ""}',
      ),
      trailing: IconButton(
        key: ValueKey('revoke-invitation-${invitation.id}'),
        tooltip: 'Hủy lời mời',
        icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
        onPressed: onRevoke,
      ),
    );
  }
}

class _InviteInput {
  final String? email;
  final GroupRole role;
  const _InviteInput({this.email, required this.role});
}

/// Vai trò được mời không được là chủ nhóm (theo API). [email] để trống = tạo lời mời qua link.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  GroupRole _role = GroupRole.member;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invitableRoles = GroupRole.values.where((r) => r != GroupRole.owner).toList();
    return AlertDialog(
      title: const Text('Mời thành viên'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email (để trống để tạo lời mời qua link)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GroupRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: invitableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _InviteInput(email: _email.text.trim().isEmpty ? null : _email.text.trim(), role: _role),
          ),
          child: const Text('Mời'),
        ),
      ],
    );
  }
}
