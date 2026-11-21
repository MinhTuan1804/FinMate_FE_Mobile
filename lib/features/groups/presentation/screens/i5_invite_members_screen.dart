import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/groups/presentation/group_type_icons.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// I5 — Mời vào nhóm (Figma). Hai cách: mã/link/QR chung của nhóm (luôn hiện sẵn, không hết hạn, ai có mã đều vào với vai trò Thành viên;
/// đặt lại hoặc tắt được) và lời mời qua email (chọn vai trò, có hạn, dùng một lần).
/// Mời trực tiếp theo FinMate ID/email đã xác minh (`GET /users/search`) đã được gỡ khỏi màn này.
class I5InviteMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const I5InviteMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<I5InviteMembersScreen> createState() => _I5InviteMembersScreenState();
}

class _I5InviteMembersScreenState extends ConsumerState<I5InviteMembersScreen> {
  final _email = TextEditingController();
  final _message = TextEditingController();
  GroupRole? _role;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  List<GroupRole> _invitableRoles(GroupRole myRole) =>
      GroupRole.values.where((r) => r.index > myRole.index).toList();

  Future<void> _submitEmail(GroupRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_email.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nhập email người cần mời.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(groupsRepositoryProvider).createInvitation(
            groupId: widget.groupId,
            email: _email.text.trim(),
            message: _message.text.trim(),
            role: role,
          );
      ref.invalidate(groupInvitationsProvider(widget.groupId));
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo lời mời, email sẽ được gửi')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _revokeInvitation(GroupInvitationEntity invitation) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Hủy lời mời',
      message: 'Hủy lời mời ${invitation.email ?? "qua link"}?',
      confirmLabel: 'Hủy lời mời',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).revokeInvitation(groupId: widget.groupId, invitationId: invitation.id);
      ref.invalidate(groupInvitationsProvider(widget.groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã hủy lời mời')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  /// `DELETE /groups/{id}/invitations` thu hồi mọi lời mời đang chờ trong một lần và trả số đã thu hồi.
  Future<void> _revokeAll(List<GroupInvitationEntity> invitations) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Thu hồi tất cả',
      message: 'Hủy ${invitations.length} lời mời đang chờ? Các mã/link đã gửi sẽ không dùng được nữa.',
      confirmLabel: 'Thu hồi',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final revoked = await ref.read(groupsRepositoryProvider).revokeAllInvitations(widget.groupId);
      ref.invalidate(groupInvitationsProvider(widget.groupId));
      messenger.showSnackBar(SnackBar(content: Text('Đã thu hồi $revoked lời mời')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final invitationsAsync = ref.watch(groupInvitationsProvider(widget.groupId));

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Mời vào nhóm', style: GlassTypography.headlineSm()),
          actions: [
            TextButton(key: const ValueKey('cancel-invite'), onPressed: () => context.pop(), child: const Text('Hủy')),
          ],
        ),
        body: SafeArea(
          child: groupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger))),
            data: (group) {
              final invitableRoles = _invitableRoles(group.myRole);
              _role ??= invitableRoles.isEmpty ? null : invitableRoles.first;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  GlassCard(
                    child: Row(
                      children: [
                        Icon(groupTypeIcon(group.type), color: groupTypeColor(group.type), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.name, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                              Text('${group.memberCount} thành viên', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (invitableRoles.isEmpty)
                    GlassCard(
                      child: Text('Vai trò của bạn không được phép mời thêm thành viên.', style: GlassTypography.bodyMd()),
                    )
                  else ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vai trò khi mời qua email', style: GlassTypography.headlineSm()),
                          const SizedBox(height: 4),
                          Text('Mã/link chung bên dưới luôn vào nhóm với vai trò Thành viên.', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
                          const SizedBox(height: 12),
                          // Một hàng, chia đều bề rộng để 3 vai trò không xuống dòng; chữ tự thu nhỏ nếu hẹp.
                          Row(
                            children: [
                              for (var i = 0; i < invitableRoles.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    key: ValueKey('invite-role-${invitableRoles[i].apiValue}'),
                                    showCheckmark: false,
                                    padding: EdgeInsets.zero,
                                    label: SizedBox(
                                      width: double.infinity,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          invitableRoles[i].label,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _role == invitableRoles[i] ? GlassColors.activeFg : GlassColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    selectedColor: GlassColors.activeFill,
                                    selected: _role == invitableRoles[i],
                                    onSelected: (_) => setState(() => _role = invitableRoles[i]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _JoinLinkCard(groupId: widget.groupId, groupName: group.name),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mời qua email', style: GlassTypography.headlineSm()),
                          const SizedBox(height: 4),
                          Text('Người nhận sẽ nhận thư mời có liên kết tham gia.', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('invite-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'email@vidu.com'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey('invite-message'),
                            controller: _message,
                            maxLength: 200,
                            decoration: const InputDecoration(hintText: 'Lời nhắn kèm theo (không bắt buộc)'),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: AsyncActionBuilder(
                              onPressed: _submitting || _role == null ? null : () => _submitEmail(_role!),
                              builder: (_, onTap, running) => OutlinedButton(
                                key: const ValueKey('submit-invite'),
                                onPressed: onTap,
                                child: running ? const ButtonLoadingIndicator() : const Text('Gửi lời mời qua email'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Text('Lời mời đang chờ', style: GlassTypography.headlineSm())),
                      if ((invitationsAsync.valueOrNull?.length ?? 0) > 1)
                        AsyncActionBuilder(
                          onPressed: () => _revokeAll(invitationsAsync.value!),
                          builder: (_, onTap, running) => TextButton.icon(
                            key: const ValueKey('revoke-all-invitations'),
                            onPressed: onTap,
                            icon: running ? const ButtonLoadingIndicator(size: 16) : Icon(LucideIcons.unlink, size: 16, color: GlassColors.danger),
                            label: Text('Thu hồi tất cả', style: TextStyle(color: GlassColors.danger)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  invitationsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger)),
                    data: (invitations) {
                      if (invitations.isEmpty) return Text('Chưa có lời mời nào đang chờ.', style: GlassTypography.bodySm(color: GlassColors.textMuted));
                      return Column(
                        children: invitations
                            .map((inv) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.mail, size: 20, color: GlassColors.textSecondary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(inv.email ?? 'Mời qua link', style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                                              Text(
                                                '${inv.role.label} · Hết hạn ${DateFormat('dd/MM/yyyy').format(inv.expiresAt)}'
                                                '${inv.emailSent == false ? " · Gửi email thất bại" : ""}',
                                                style: GlassTypography.bodySm(color: GlassColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          key: ValueKey('revoke-invitation-${inv.id}'),
                                          tooltip: 'Hủy lời mời',
                                          icon: Icon(LucideIcons.trash2, size: 18, color: GlassColors.danger),
                                          onPressed: () => _revokeInvitation(inv),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      );
                    },
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

/// Mã/link/QR chung của nhóm: hiện sẵn ngay khi mở màn, không phải bấm tạo, không hết hạn, dùng nhiều lần.
class _JoinLinkCard extends ConsumerWidget {
  final String groupId;
  final String groupName;
  const _JoinLinkCard({required this.groupId, required this.groupName});

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Đặt lại mã',
      message: 'Tạo mã mới và vô hiệu mã hiện tại? Link/QR đã chia sẻ trước đó sẽ không dùng được nữa.',
      confirmLabel: 'Đặt lại',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).resetJoinLink(groupId);
      ref.invalidate(groupJoinLinkProvider(groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã đặt lại mã')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _setEnabled(BuildContext context, WidgetRef ref, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).setJoinLinkEnabled(groupId, enabled);
      ref.invalidate(groupJoinLinkProvider(groupId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkAsync = ref.watch(groupJoinLinkProvider(groupId));
    return GlassCard(
      key: const ValueKey('smart-link-card'),
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: linkAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger)),
        data: (link) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.link, size: 18, color: GlassColors.accentSkyBlue),
                const SizedBox(width: 8),
                Expanded(child: Text('Mã & link tham gia nhóm', style: GlassTypography.headlineSm())),
                const GlassBadge(text: 'Không hết hạn'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ai có mã hoặc link này đều tham gia được với vai trò ${link.role.label}. Dùng được nhiều lần.',
              style: GlassTypography.bodySm(color: GlassColors.textMuted),
            ),
            const SizedBox(height: 12),
            Center(
              child: Opacity(
                opacity: link.enabled ? 1 : 0.35,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: GlassRadius.roundedCard),
                  child: QrImageView(data: link.joinUrl, size: 180, backgroundColor: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Quét QR, mở link, hoặc dán vào mục "Nhập mã lời mời" trong app FinMate', style: GlassTypography.bodySm(color: GlassColors.textMuted), textAlign: TextAlign.center)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedCard),
              child: SelectableText(link.joinUrl, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('copy-invite-code'),
                    onPressed: link.enabled
                        ? () {
                            Clipboard.setData(ClipboardData(text: link.joinUrl));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép link tham gia')));
                          }
                        : null,
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Sao chép', maxLines: 1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('share-invite-code'),
                    onPressed: link.enabled
                        ? () => Share.share(
                              'Mời bạn tham gia nhóm "$groupName" trên FinMate.\n'
                              'Link tham gia: ${link.joinUrl}\n'
                              'Mở app FinMate → "Nhập mã lời mời" → dán link này để tham gia.',
                            )
                        : null,
                    icon: const Icon(LucideIcons.share2, size: 16),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Chia sẻ', maxLines: 1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Cho phép tham gia bằng mã này', style: GlassTypography.bodyMd(color: GlassColors.textPrimary))),
                Switch(
                  key: const ValueKey('join-link-switch'),
                  value: link.enabled,
                  onChanged: (v) => _setEnabled(context, ref, v),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AsyncActionBuilder(
                onPressed: () => _reset(context, ref),
                builder: (_, onTap, running) => TextButton.icon(
                  key: const ValueKey('reset-join-link'),
                  onPressed: onTap,
                  icon: running ? const ButtonLoadingIndicator(size: 16) : Icon(LucideIcons.refreshCw, size: 16, color: GlassColors.danger),
                  label: Text('Đặt lại mã', style: TextStyle(color: GlassColors.danger)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
