import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';

/// Màn danh sách nhóm: tạo nhóm mới, bấm vào một nhóm để xem chi tiết.
/// Đơn giản để test nhanh toàn bộ API groups còn thiếu ở FE.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_GroupInput>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsControllerProvider.notifier).create(name: result.name, type: result.type);
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo nhóm')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(groupsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhóm tài chính'),
        actions: [
          IconButton(
            key: const ValueKey('accept-invitation-entry'),
            tooltip: 'Nhập mã lời mời',
            icon: const Icon(LucideIcons.mail),
            onPressed: () => context.push('/accept-invitation'),
          ),
          IconButton(
            key: const ValueKey('add-group'),
            tooltip: 'Tạo nhóm',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(errorMessage(e), style: AppTypography.body(context))),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(child: Text('Chưa tham gia nhóm nào.', style: AppTypography.body(context)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _buildCard(context, groups[i], isDark),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, GroupEntity group, bool isDark) {
    return InkWell(
      key: ValueKey('group-${group.id}'),
      onTap: () => context.push('/group-detail', extra: group.id),
      borderRadius: AppSpacing.roundedMedium,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedMedium,
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.users, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${group.type.label} · ${group.memberCount} thành viên',
                    style: AppTypography.caption(context),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(group.myRole.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupInput {
  final String name;
  final GroupType type;
  const _GroupInput({required this.name, required this.type});
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _name = TextEditingController();
  GroupType _type = GroupType.family;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên nhóm');
      return;
    }
    Navigator.pop(context, _GroupInput(name: name, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo nhóm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên nhóm (ví dụ: Gia đình, Quỹ phòng trọ)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<GroupType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Loại nhóm'),
            items: GroupType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _submit, child: const Text('Tạo')),
      ],
    );
  }
}
