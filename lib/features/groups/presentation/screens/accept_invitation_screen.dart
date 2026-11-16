import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/data/group_invitations_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/groups/presentation/group_type_icons.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// I6 — Chấp nhận lời mời (Stitch `i6_accept_invitation`). App chưa có app-link/deep-link xử lý
/// lời mời (xem quyết định phạm vi I4/I5), nên vẫn giữ bước nhập mã (token) thủ công trước khi
/// hiện thẻ xem trước — Stitch coi như mã đã có sẵn từ link, FE thêm bước này vì chưa deep-link được.
/// Thẻ xem trước CHỈ hiện đúng field `GET /group-invitations/preview` trả về (groupName, groupType,
/// role, invitedBy, expiresAt) — BỎ lời nhắn cá nhân, "Quỹ chung hiện có", "Nguồn tiền liên kết mặc
/// định" của Stitch vì API không trả 3 thứ này (quyết định phạm vi Luồng 8a).
class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  ConsumerState<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends ConsumerState<AcceptInvitationScreen> {
  final _token = TextEditingController();
  GroupInvitationPreviewEntity? _preview;
  bool _loading = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _doPreview() async {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final preview = await ref.read(groupInvitationsRepositoryProvider).preview(token);
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final groupId = await ref.read(groupInvitationsRepositoryProvider).accept(token);
      ref.read(groupsControllerProvider.notifier).load();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Đã tham gia nhóm')));
        context.push('/group-detail', extra: groupId);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Không có API decline cho người được mời (lời mời tự hết hạn nếu không chấp nhận) — chỉ đóng màn.
  void _decline() => context.pop();

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
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
                      'Dán mã bạn nhận được qua QR, link hoặc tin nhắn chia sẻ.',
                      style: GlassTypography.bodySm(color: GlassColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('invitation-token'),
                      controller: _token,
                      decoration: const InputDecoration(hintText: 'Mã lời mời (token)'),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const ValueKey('accept-invitation'),
                    onPressed: _loading ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassColors.ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                    ),
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.userPlus, size: 18),
                    label: Text('Chấp nhận & Tham gia nhóm', style: GlassTypography.buttonText()),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    key: const ValueKey('decline-invitation'),
                    onPressed: _loading ? null : _decline,
                    child: Text('Từ chối lời mời', style: GlassTypography.bodyMd(color: GlassColors.textMuted)),
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
    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.invitedBy != null) ...[
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
                    '${preview.invitedBy} đã mời bạn tham gia',
                    style: GlassTypography.bodySm(color: GlassColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(groupTypeIcon(preview.groupType), color: groupTypeColor(preview.groupType), size: 32),
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
              GlassBadge(text: 'Vai trò: ${preview.role.label}', color: GlassColors.accentSkyBlue),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: GlassColors.glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 16, color: GlassColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Hết hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(preview.expiresAt.toLocal())}',
                style: GlassTypography.bodySm(color: GlassColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
