import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/groups/data/group_invitations_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';

/// Màn nhập mã lời mời (token) để xem trước rồi tham gia nhóm.
/// Đơn giản để test nhanh API group-invitations (preview/accept) còn thiếu ở FE.
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
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
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
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập mã lời mời')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('invitation-token'),
              controller: _token,
              decoration: const InputDecoration(labelText: 'Mã lời mời (token)'),
              onChanged: (_) => setState(() => _preview = null),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('preview-invitation'),
              onPressed: _loading ? null : _doPreview,
              child: const Text('Xem trước'),
            ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: AppSpacing.roundedMedium,
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preview.groupName, style: AppTypography.h3(context)),
                    const SizedBox(height: 4),
                    Text('${preview.groupType.label} · Vai trò: ${preview.role.label}', style: AppTypography.caption(context)),
                    if (preview.invitedBy != null) Text('Được mời bởi: ${preview.invitedBy}', style: AppTypography.caption(context)),
                    Text(
                      'Hết hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(preview.expiresAt.toLocal())}',
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const ValueKey('accept-invitation'),
                onPressed: _loading ? null : _accept,
                child: const Text('Tham gia nhóm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
