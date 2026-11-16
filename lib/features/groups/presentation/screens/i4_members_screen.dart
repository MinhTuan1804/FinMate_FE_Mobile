import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';

/// I4 — Thành viên nhóm (Stitch `i4_members`). BỎ banner "ứng trước cho nhóm"/"nhắc thanh toán" và
/// dòng nợ từng thành viên của Stitch — hệ thống thật chỉ có 1 sổ quỹ chung (Phase 85), không có khái
/// niệm nợ giữa 2 thành viên (xem quyết định phạm vi Luồng 8a). Thay bằng số dư quỹ chung thật +
/// "Đã góp: X đ" mỗi thành viên (`GET /funds/{fundId}/summary`). "Thủ quỹ" (nhãn Stitch) không tồn
/// tại — map đúng 4 vai trò thật `GroupRole` (Owner/Manager/Member/Viewer). Các hành động quản trị
/// thành viên (đổi vai trò, xóa, chuyển quyền chủ nhóm) dời từ bottom sheet cũ của I3 sang đây.
class I4MembersScreen extends ConsumerWidget {
  final String groupId;
  const I4MembersScreen({super.key, required this.groupId});

  Future<void> _changeRole(BuildContext context, WidgetRef ref, GroupMemberEntity member) async {
    final picked = await GlassDialog.choice<GroupRole>(
      context,
      title: 'Đổi vai trò của ${member.displayName}',
      options: GroupRole.values,
      labelOf: (r) => r.label,
      isSelected: (r) => r == member.role,
    );
    if (picked == null || picked == member.role || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).updateMember(groupId: groupId, userId: member.userId, role: picked);
      ref.invalidate(groupMembersProvider(groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã đổi vai trò')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, GroupMemberEntity member) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Xóa thành viên',
      message: 'Xóa ${member.displayName} khỏi nhóm?',
      confirmLabel: 'Xóa',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).removeMember(groupId: groupId, userId: member.userId);
      ref.invalidate(groupMembersProvider(groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa thành viên')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _transferOwnership(BuildContext context, WidgetRef ref, List<GroupMemberEntity> members, String myUserId) async {
    final candidates = members.where((m) => m.userId != myUserId).toList();
    if (candidates.isEmpty) return;
    final picked = await GlassDialog.choice<GroupMemberEntity>(
      context,
      title: 'Chuyển quyền chủ nhóm cho',
      options: candidates,
      labelOf: (m) => m.displayName,
    );
    if (picked == null || !context.mounted) return;
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Xác nhận chuyển quyền chủ nhóm',
      message: 'Chuyển quyền chủ nhóm cho ${picked.displayName}? Bạn sẽ trở thành quản lý.',
      confirmLabel: 'Chuyển',
      cancelLabel: 'Không',
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).transferOwnership(groupId: groupId, newOwnerUserId: picked.userId);
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupMembersProvider(groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã chuyển quyền chủ nhóm')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final fundAsync = ref.watch(groupPrimaryFundProvider(groupId));
    final myUserId = ref.watch(currentUserIdProvider) ?? '';

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: groupAsync.maybeWhen(
            data: (g) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Thành viên nhóm (${g.memberCount})', style: GlassTypography.headlineSm()),
                Text('TÀI CHÍNH NHÓM', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
              ],
            ),
            orElse: () => Text('Thành viên nhóm', style: GlassTypography.headlineSm()),
          ),
          actions: [
            groupAsync.maybeWhen(
              data: (g) => g.myPermissions.contains(GroupPermission.inviteMembers) || g.isOwner
                  ? IconButton(
                      key: const ValueKey('go-invite'),
                      tooltip: 'Mời thêm thành viên',
                      icon: Icon(LucideIcons.userPlus, color: GlassColors.textPrimary),
                      onPressed: () => context.push('/group-invite', extra: groupId),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: SafeArea(
          child: groupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger))),
            data: (group) => membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger))),
              data: (members) {
                final fundId = fundAsync.valueOrNull?.id;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (fundId != null) _FundStatusCard(groupId: groupId, fundId: fundId),
                    if (fundId != null) const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Thành viên trong nhóm', style: GlassTypography.headlineSm()),
                        Text('${members.length} THÀNH VIÊN', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...members.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MemberCard(
                            member: entry.value,
                            colorIndex: entry.key,
                            isMe: entry.value.userId == myUserId,
                            groupId: groupId,
                            fundId: fundId,
                            canManage: group.isOwner,
                            onChangeRole: () => _changeRole(context, ref, entry.value),
                            onRemove: () => _removeMember(context, ref, entry.value),
                          ),
                        )),
                    if (group.isOwner) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        key: const ValueKey('transfer-ownership'),
                        onPressed: () => _transferOwnership(context, ref, members, myUserId),
                        icon: const Icon(LucideIcons.users, size: 16),
                        label: const Text('Chuyển quyền chủ nhóm'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _PermissionsLegendCard(),
                    const SizedBox(height: 20),
                    if (group.myPermissions.contains(GroupPermission.inviteMembers) || group.isOwner)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          key: const ValueKey('invite-more-members'),
                          onPressed: () => context.push('/group-invite', extra: groupId),
                          icon: const Icon(LucideIcons.link, size: 18),
                          label: const Text('Mời thêm thành viên mới'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlassColors.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FundStatusCard extends ConsumerWidget {
  final String groupId;
  final String fundId;
  const _FundStatusCard({required this.groupId, required this.fundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundAsync = ref.watch(groupPrimaryFundProvider(groupId));
    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TÌNH TRẠNG QUỸ CHUNG', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
              const GlassBadge(text: 'Đã đồng bộ', color: GlassColors.success),
            ],
          ),
          const SizedBox(height: 8),
          fundAsync.when(
            loading: () => Text('…', style: GlassTypography.displayHero()),
            error: (_, __) => Text('—', style: GlassTypography.displayHero()),
            data: (fund) => fund == null
                ? Text('Chưa có quỹ chung.', style: GlassTypography.bodyMd())
                : Text(fund.formattedBalance, style: GlassTypography.displayHero(color: fund.isNegative ? GlassColors.danger : GlassColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final GroupMemberEntity member;
  final int colorIndex;
  final bool isMe;
  final bool canManage;
  final String groupId;
  final String? fundId;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.colorIndex,
    required this.isMe,
    required this.canManage,
    required this.groupId,
    required this.fundId,
    required this.onChangeRole,
    required this.onRemove,
  });

  static const _avatarColors = [GlassColors.accentSkyBlue, GlassColors.accentDustyRose, GlassColors.accentWarmPeach];

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[colorIndex % _avatarColors.length];
    final initial = member.displayName.isEmpty ? '?' : member.displayName[0].toUpperCase();
    return GlassCard(
      key: ValueKey('member-${member.userId}'),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.25), child: Text(initial, style: GlassTypography.headlineSm(color: color))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(member.displayName, style: GlassTypography.bodyMd(color: GlassColors.textPrimary), overflow: TextOverflow.ellipsis)),
                    if (isMe) ...[const SizedBox(width: 6), const GlassBadge(text: 'Bạn')],
                  ],
                ),
                const SizedBox(height: 4),
                GlassBadge(text: member.role.label, color: member.role == GroupRole.owner ? GlassColors.success : GlassColors.textSecondary),
                if (fundId != null) _ContributionLine(groupId: groupId, fundId: fundId!, userId: member.userId),
              ],
            ),
          ),
          if (canManage && !isMe)
            Row(
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
                  icon: Icon(LucideIcons.trash2, size: 18, color: GlassColors.danger),
                  onPressed: onRemove,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Đã góp: X đ" thật từ `GET /funds/{fundId}/summary` → `contributionsByMember` — thay cho dòng
/// "Cần nợ"/"Nợ bạn" của Stitch (không có trong hệ thống thật, xem quyết định phạm vi Luồng 8a).
class _ContributionLine extends ConsumerWidget {
  final String groupId;
  final String fundId;
  final String userId;
  const _ContributionLine({required this.groupId, required this.fundId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(groupFundSummaryProvider((groupId, fundId)));
    return summaryAsync.maybeWhen(
      data: (summary) {
        for (final c in summary.contributionsByMember) {
          if (c.userId == userId) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Đã góp: ${c.formattedAmount}', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
            );
          }
        }
        return const SizedBox.shrink();
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PermissionsLegendCard extends StatelessWidget {
  const _PermissionsLegendCard();

  static const _descriptions = {
    GroupRole.owner: 'Toàn quyền — duy nhất 1 người, có thể xóa nhóm',
    GroupRole.manager: 'Quản lý nhóm, mời/xóa thành viên cấp thấp hơn',
    GroupRole.member: 'Ghi/xem quỹ chung, giao dịch đã chia sẻ',
    GroupRole.viewer: 'Chỉ xem, không ghi/sửa được dữ liệu nhóm',
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 18, color: GlassColors.textSecondary),
              const SizedBox(width: 8),
              Text('Quyền hạn trong nhóm', style: GlassTypography.headlineSm()),
            ],
          ),
          const SizedBox(height: 4),
          Text('Quy chế tự động theo phân cấp bảo mật', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
          const SizedBox(height: 12),
          ...GroupRole.values.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(r.label, style: GlassTypography.bodyMd())),
                    Expanded(flex: 2, child: Text(_descriptions[r] ?? '', style: GlassTypography.bodySm(color: GlassColors.textMuted))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
