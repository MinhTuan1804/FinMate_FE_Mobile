import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/groups/data/group_invitations_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/groups/presentation/group_type_icons.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Dán cả đường dẫn `https://finmate.app/join/<token>` hay chỉ mã đều được: lấy phần token cuối đường dẫn.
String extractInvitationToken(String input) {
  final text = input.trim();
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme && uri.pathSegments.length >= 2 && uri.pathSegments[uri.pathSegments.length - 2] == 'join') {
    return uri.pathSegments.last;
  }
  return text;
}

/// I6 — Nhận lời mời (Figma). Nhập/dán mã hoặc đường dẫn `finmate.app/join/<token>` → xem trước → nhận hoặc từ chối bằng token.
/// Chọn ví làm nguồn tiền mặc định: server chỉ lưu lại, khi góp quỹ/ghi chi app vẫn phải tự truyền ví.
class AcceptInvitationScreen extends ConsumerStatefulWidget {
  /// Mã lấy sẵn từ deep link `finmate.app/join/<token>`; có thì xem trước ngay.
  final String? initialToken;
  const AcceptInvitationScreen({super.key, this.initialToken});

  @override
  ConsumerState<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends ConsumerState<AcceptInvitationScreen> {
  final _token = TextEditingController();
  GroupInvitationPreviewEntity? _preview;

  /// Token của lời mời đang xem.
  String? _activeToken;
  String? _walletId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialToken;
    if (initial != null && initial.isNotEmpty) {
      _token.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _doPreview());
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _doPreview() async {
    final token = extractInvitationToken(_token.text);
    if (token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final preview = await ref.read(groupInvitationsRepositoryProvider).preview(token);
      if (mounted) {
        setState(() {
          _preview = preview;
          _activeToken = token;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final preview = _preview;
    if (preview == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final groupId = await ref.read(groupInvitationsRepositoryProvider).accept(
            token: _activeToken,
            defaultFinancialAccountId: _walletId,
          );
      ref.read(groupsControllerProvider.notifier).load();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Đã tham gia nhóm')));
        // Thay màn nhận lời mời: bấm quay lại từ nhóm không được về màn này với lời mời cũ như thể chưa tham gia.
        context.pushReplacement('/group-detail', extra: groupId);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    final preview = _preview;
    if (preview == null) return;
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Từ chối lời mời',
      message: 'Từ chối lời mời vào nhóm "${preview.groupName}"? Mã này sẽ không dùng lại được.',
      confirmLabel: 'Từ chối',
      cancelLabel: 'Không',
      isDanger: true,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(groupInvitationsRepositoryProvider).decline(token: _activeToken);
      messenger.showSnackBar(const SnackBar(content: Text('Đã từ chối lời mời')));
      if (router.canPop()) router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Lời mời tham gia nhóm', style: GlassTypography.headlineSm()),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nhập mã lời mời', style: GlassTypography.headlineSm()),
                    const SizedBox(height: 4),
                    Text(
                      'Dán mã hoặc đường dẫn bạn nhận được qua QR, link hay tin nhắn chia sẻ.',
                      style: GlassTypography.bodySm(color: GlassColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('invitation-token'),
                      controller: _token,
                      decoration: const InputDecoration(hintText: 'Mã hoặc link lời mời'),
                      onChanged: (_) => setState(() => _preview = null),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        key: const ValueKey('preview-invitation'),
                        onPressed: _loading ? null : _doPreview,
                        child: _loading && preview == null
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Xem trước'),
                      ),
                    ),
                  ],
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 16),
                _InvitationPreviewCard(preview: preview),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NGUỒN TIỀN LIÊN KẾT MẶC ĐỊNH', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                        const SizedBox(height: 8),
                        for (final a in accounts)
                          InkWell(
                            key: ValueKey('wallet-${a.id}'),
                            borderRadius: GlassRadius.roundedCard,
                            onTap: () => setState(() => _walletId = _walletId == a.id ? null : a.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.landmark, size: 20, color: GlassColors.accentSkyBlue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.name, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                                        Text('Khả dụng: ${formatVnd(a.balanceCents)}', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _walletId == a.id ? LucideIcons.circleCheck : LucideIcons.circle,
                                    size: 22,
                                    color: _walletId == a.id ? GlassColors.ink : GlassColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const ValueKey('accept-invitation'),
                    onPressed: _loading ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassColors.ink,
                      foregroundColor: GlassColors.onInk,
                      shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                    ),
                    icon: _loading
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: GlassColors.onInk))
                        : const Icon(LucideIcons.userPlus, size: 18),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Chấp nhận & Tham gia nhóm', style: GlassTypography.buttonText(), maxLines: 1)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: AsyncActionBuilder(
                    onPressed: _loading ? null : _decline,
                    builder: (_, onTap, running) => TextButton(
                      key: const ValueKey('decline-invitation'),
                      onPressed: onTap,
                      child: running ? const ButtonLoadingIndicator() : Text('Từ chối lời mời', style: GlassTypography.bodyMd(color: GlassColors.textMuted)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationPreviewCard extends StatelessWidget {
  final GroupInvitationPreviewEntity preview;
  const _InvitationPreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final inviter = preview.invitedBy;
    final inviterRole = preview.invitedByRole;
    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inviter != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: GlassColors.secondarySurface,
                  child: Icon(LucideIcons.user, size: 14, color: GlassColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$inviter${inviterRole == null ? "" : " (${inviterRole.label})"} đã mời bạn tham gia',
                    style: GlassTypography.bodySm(color: GlassColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(groupIconFor(preview.groupIcon, preview.groupType), color: groupTypeColor(preview.groupType), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(preview.groupName, style: GlassTypography.headlineMd()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassBadge(text: preview.groupType.label),
              if (preview.memberCount != null) GlassBadge(text: '${preview.memberCount} thành viên hiện tại'),
              GlassBadge(text: 'Vai trò: ${preview.role.label}', color: GlassColors.accentSkyBlue),
            ],
          ),
          if (preview.fundBalanceCents != null) ...[
            const SizedBox(height: 16),
            Center(child: Text('QUỸ CHUNG HIỆN CÓ', style: GlassTypography.labelCaps(color: GlassColors.textMuted))),
            const SizedBox(height: 4),
            Center(child: Text(formatVnd(preview.fundBalanceCents!), style: GlassTypography.displayHero())),
          ],
          if (preview.message != null && preview.message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedCard),
              child: Text('“${preview.message}”', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: GlassColors.glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 16, color: GlassColors.textMuted),
              const SizedBox(width: 8),
              Text(
                preview.expiresAt == null ? 'Mã của nhóm, không hết hạn' : 'Hết hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(preview.expiresAt!.toLocal())}',
                style: GlassTypography.bodySm(color: GlassColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
