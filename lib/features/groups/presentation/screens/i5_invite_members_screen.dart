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

/// I5 — Mời vào nhóm (Stitch `i5_invite_members`). BỎ "Mời trực tiếp" tìm theo FinMate ID/danh bạ
/// (không có API tìm người dùng) và nhãn "HẠN 7 NGÀY" cứng (chỉ hiện hạn thật sau khi tạo lời mời) —
/// xem quyết định phạm vi Luồng 8a. Link mời web thật (`finmate.app/join/...`) và quét QR tự mở app
/// CHƯA làm được — app chưa có app-link/deep-link nào xử lý lời mời (quyết định 2026-11-16: để đợt
/// sau). Đợt này: tạo lời mời qua `POST /groups/{id}/invitations`, hiện mã lời mời dưới dạng QR +
/// text để Sao chép/Chia sẻ — người nhận tự dán mã vào màn "Nhập mã lời mời" (`/accept-invitation`,
/// I6) đã có sẵn.
class I5InviteMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const I5InviteMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<I5InviteMembersScreen> createState() => _I5InviteMembersScreenState();
}

class _I5InviteMembersScreenState extends ConsumerState<I5InviteMembersScreen> {
  final _email = TextEditingController();
  GroupRole? _role;
  bool _submitting = false;
  GroupInvitationEntity? _created;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  List<GroupRole> _invitableRoles(GroupRole myRole) =>
      GroupRole.values.where((r) => r.index > myRole.index).toList();

  Future<void> _submit(GroupRole role) async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(groupsRepositoryProvider).createInvitation(
            groupId: widget.groupId,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            role: role,
          );
      ref.invalidate(groupInvitationsProvider(widget.groupId));
      if (!mounted) return;
      setState(() {
        _created = created;
        _submitting = false;
      });
      if (created.token == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Đã tạo lời mời, email sẽ được gửi')));
      }
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
                          Text('Vai trò khi tham gia', style: GlassTypography.headlineSm()),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: invitableRoles
                                .map((r) => ChoiceChip(
                                      key: ValueKey('invite-role-${r.apiValue}'),
                                      label: Text(r.label),
                                      selected: _role == r,
                                      onSelected: (_) => setState(() {
                                        _role = r;
                                        _created = null;
                                      }),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mời qua email (không bắt buộc)', style: GlassTypography.headlineSm()),
                          const SizedBox(height: 4),
                          Text('Để trống để tạo mã lời mời dùng chung (QR/link).', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('invite-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'email@vidu.com'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              key: const ValueKey('submit-invite'),
                              onPressed: _submitting || _role == null ? null : () => _submit(_role!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GlassColors.ink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                              ),
                              child: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text('Tạo lời mời', style: GlassTypography.buttonText()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_created?.token != null) ...[
                      const SizedBox(height: 16),
                      _InviteCodeCard(groupName: group.name, invitation: _created!),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Text('Lời mời đang chờ', style: GlassTypography.headlineSm()),
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

class _InviteCodeCard extends StatelessWidget {
  final String groupName;
  final GroupInvitationEntity invitation;
  const _InviteCodeCard({required this.groupName, required this.invitation});

  @override
  Widget build(BuildContext context) {
    final token = invitation.token!;
    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MÃ LỜI MỜI', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
              GlassBadge(text: 'Hết hạn ${DateFormat('dd/MM/yyyy').format(invitation.expiresAt)}'),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: GlassRadius.roundedCard),
              child: QrImageView(data: token, size: 180, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('Dán mã này vào mục "Nhập mã lời mời" trong app FinMate', style: GlassTypography.bodySm(color: GlassColors.textMuted), textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedCard),
            child: SelectableText(token, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('copy-invite-code'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã lời mời')));
                  },
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Sao chép', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('share-invite-code'),
                  onPressed: () => Share.share(
                    'Mời bạn tham gia nhóm "$groupName" trên FinMate.\n'
                    'Mã lời mời: $token\n'
                    'Mở app FinMate → "Nhập mã lời mời" → dán mã này để tham gia.',
                  ),
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Chia sẻ', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
