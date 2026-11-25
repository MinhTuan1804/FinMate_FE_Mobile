import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/groups/presentation/group_type_icons.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

enum _GroupSort {
  recent('Gần đây'),
  name('Tên A–Z');

  final String label;
  const _GroupSort(this.label);
}

/// I1 — Danh sách nhóm (Stitch `i1_group_list`). Hero tổng chi tháng này cộng dồn mọi nhóm, không có
/// dòng "Cần thanh toán"/thẻ cấn trừ nợ AI (hệ thống thật là quỹ chung 1 sổ duy nhất, không phải chia
/// nợ từng khoản — xem quyết định phạm vi Luồng 8a). Loại nhóm chỉ 2 giá trị thật (Family/Other).
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  /// null = Tất cả; còn lại lọc theo loại nhóm (chỉ hiện chip của loại đang có nhóm).
  GroupType? _typeFilter;
  _GroupSort _sort = _GroupSort.recent;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Nhóm tài chính', style: GlassTypography.headlineMd()),
          actions: [
            IconButton(
              key: const ValueKey('accept-invitation-entry'),
              tooltip: 'Nhập mã lời mời',
              icon: Icon(LucideIcons.mail, color: GlassColors.textPrimary),
              onPressed: () => context.push('/accept-invitation'),
            ),
          ],
        ),
        body: SafeArea(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.read(groupsControllerProvider.notifier).load(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
            data: (groups) => _buildContent(context, groups),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              key: const ValueKey('create-group'),
              onPressed: () => context.push('/groups/create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlassColors.ink,
                foregroundColor: GlassColors.onInk,
                shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
              ),
              icon: const Icon(LucideIcons.userPlus, size: 18),
              label: FittedBox(fit: BoxFit.scaleDown, child: Text('Tạo nhóm mới', style: GlassTypography.buttonText(), maxLines: 1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<GroupEntity> groups) {
    final byType = _typeFilter == null ? groups : groups.where((g) => g.type == _typeFilter).toList();
    final filtered = [...byType]
      ..sort(switch (_sort) {
        _GroupSort.recent => (a, b) => b.createdAt.compareTo(a.createdAt),
        _GroupSort.name => (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      });
    final presentTypes = GroupType.values.where((t) => groups.any((g) => g.type == t)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        _HeroCard(groupCount: groups.length, groups: groups),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GlassFilterChip(
                key: const ValueKey('group-filter-all'),
                label: 'Tất cả',
                count: groups.length,
                selected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              for (final t in presentTypes) ...[
                const SizedBox(width: 8),
                GlassFilterChip(
                  key: ValueKey('group-filter-${t.apiValue.toLowerCase()}'),
                  label: t.label,
                  count: groups.where((g) => g.type == t).length,
                  selected: _typeFilter == t,
                  onTap: () => setState(() => _typeFilter = t),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Nhóm đang tham gia', style: GlassTypography.headlineSm())),
            PopupMenuButton<_GroupSort>(
              key: const ValueKey('group-sort'),
              tooltip: 'Sắp xếp nhóm',
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => [
                for (final s in _GroupSort.values) PopupMenuItem(value: s, child: Text(s.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sắp xếp: ${_sort.label}', style: GlassTypography.bodySm(color: GlassColors.accentSkyBlue)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                groups.isEmpty ? 'Chưa tham gia nhóm nào.' : 'Không có nhóm nào khớp bộ lọc.',
                style: GlassTypography.bodyMd(),
              ),
            ),
          )
        else
          ...filtered.map((g) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _GroupCard(group: g))),
        const SizedBox(height: 4),
        const _FairSplitCard(),
      ],
    );
  }
}

class _HeroCard extends ConsumerWidget {
  final int groupCount;
  final List<GroupEntity> groups;
  const _HeroCard({required this.groupCount, required this.groups});

  /// "Thanh toán": số nợ nằm ở các nhóm chia hóa đơn, nên mở thẳng nhóm đó (1 nhóm) hoặc cho chọn (nhiều nhóm).
  /// Ở trong nhóm, mục "Gợi ý cấn trừ nợ" có nút "Đã trả" để ghi nhận. FinMate chỉ ghi sổ, không chuyển tiền thật.
  Future<void> _pay(BuildContext context) async {
    final splitGroups = groups.where((g) => g.isSplitBill).toList();
    if (splitGroups.isEmpty) return;
    var target = splitGroups.first;
    if (splitGroups.length > 1) {
      final picked = await GlassDialog.choice<GroupEntity>(
        context,
        title: 'Thanh toán ở nhóm nào?',
        options: splitGroups,
        labelOf: (g) => g.name,
      );
      if (picked == null || !context.mounted) return;
      target = picked;
    }
    context.push('/group-detail', extra: target.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final summaryAsync = ref.watch(groupsSummaryProvider);
    final summary = summaryAsync.valueOrNull;
    String money(BigInt? v) => v == null ? '—' : '${NumberFormat('#,###', 'vi_VN').format(v.toInt())} ₫';
    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TỔNG KẾT THÁNG ${now.month}'.toUpperCase(), style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
              GlassBadge(text: '$groupCount nhóm đang tham gia'),
            ],
          ),
          const SizedBox(height: 8),
          Text('Tổng đã chi trong nhóm tháng này', style: GlassTypography.bodySm()),
          const SizedBox(height: 2),
          summaryAsync.when(
            loading: () => Text('…', style: GlassTypography.displayHero()),
            error: (_, __) => Text('—', style: GlassTypography.displayHero()),
            data: (s) => Text(money(s.totalSpentCents), style: GlassTypography.displayHero()),
          ),
          if (summary != null && (summary.myShareDueCents != null || summary.myPayableCents != null)) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('groups-debt-summary'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedCard),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phần bạn cần đóng', style: GlassTypography.bodySm()),
                        Text(money(summary.myShareDueCents), style: GlassTypography.labelNumeric()),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: GlassColors.glassBorder),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cần thanh toán', style: GlassTypography.bodySm()),
                        Text(
                          money(summary.myPayableCents),
                          style: GlassTypography.labelNumeric(
                            color: (summary.myPayableCents ?? BigInt.zero) > BigInt.zero ? GlassColors.danger : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (summary?.closingDate != null || ((summary?.myPayableCents ?? BigInt.zero) > BigInt.zero && groups.any((g) => g.isSplitBill))) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (summary?.closingDate != null) ...[
                  Icon(LucideIcons.clock, size: 14, color: GlassColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Hạn chốt: ${DateFormat('dd/MM').format(summary!.closingDate!)}', style: GlassTypography.bodySm()),
                ],
                const Spacer(),
                if ((summary?.myPayableCents ?? BigInt.zero) > BigInt.zero && groups.any((g) => g.isSplitBill))
                  AsyncActionBuilder(
                    onPressed: () => _pay(context),
                    builder: (_, onTap, running) => FilledButton.icon(
                      key: const ValueKey('groups-pay'),
                      onPressed: onTap,
                      icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.arrowRight, size: 16),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Thanh toán'),
                      style: FilledButton.styleFrom(backgroundColor: GlassColors.ink, foregroundColor: GlassColors.onInk, minimumSize: const Size(0, 38)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ giới thiệu cách chia nợ công bằng (Figma I1). Nội dung mô tả cách app tính, không có số liệu.
class _FairSplitCard extends StatelessWidget {
  const _FairSplitCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const ValueKey('fair-split-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: GlassColors.ink, shape: BoxShape.circle),
            child: Icon(LucideIcons.sparkles, size: 20, color: GlassColors.onInk),
          ),
          const SizedBox(height: 12),
          Text('Chia tiền công bằng & minh bạch', style: GlassTypography.headlineSm()),
          const SizedBox(height: 4),
          Text(
            'FinMate tự động đối soát nợ giữa các thành viên và gợi ý ít lượt chuyển khoản nhất để cân bằng mọi khoản.',
            style: GlassTypography.bodySm(),
          ),
          TextButton(
            key: const ValueKey('fair-split-learn'),
            onPressed: () => GlassDialog.custom<void>(
              context,
              title: 'Cách chia nợ',
              contentBuilder: (ctx, setState) => Text(
                'Mỗi hóa đơn được chia cho những người cùng dùng. Người trả trước sẽ được "nợ lại" phần của người khác.\n\n'
                'Cuối kỳ, FinMate cộng trừ mọi khoản và gợi ý các lượt chuyển tối giản: ai nợ ai bao nhiêu để cả nhóm về 0 với ít lượt chuyển nhất. '
                'Nhóm cũng có thể chọn cấn trừ thủ công trong Cài đặt nhóm.\n\n'
                'FinMate chỉ ghi nhận số nợ và việc đã trả, không chuyển tiền thật.',
                style: GlassTypography.bodyMd(),
              ),
              actionsBuilder: (ctx, setState) => GlassPrimaryButton(label: 'Đã hiểu', onPressed: () => Navigator.pop(ctx)),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: const Text('Khám phá cách chia →'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final GroupEntity group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = group.card;
    final fundBalance = card?.fundBalanceCents;
    final percent = card?.budgetUsedPercent;
    final preview = card?.memberPreview ?? const <GroupMemberPreviewEntity>[];
    final extra = group.memberCount - preview.length;
    return InkWell(
      key: ValueKey('group-${group.id}'),
      onTap: () => context.push('/group-detail', extra: group.id),
      borderRadius: GlassRadius.roundedCard,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: groupTypeColor(group.type).withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(groupIconFor(group.icon, group.type), color: groupTypeColor(group.type), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: GlassTypography.headlineSm()),
                      Text('${group.type.label} · ${group.memberCount} thành viên', style: GlassTypography.bodySm()),
                    ],
                  ),
                ),
                GlassBadge(text: group.myRole.label, color: group.isOwner ? GlassColors.accentSkyBlue : null),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
              ],
            ),
            if (fundBalance != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quỹ chung hiện có', style: GlassTypography.bodySm()),
                    Text(
                      '${NumberFormat('#,###', 'vi_VN').format(fundBalance.toInt())} ₫',
                      style: GlassTypography.labelNumeric(color: fundBalance < BigInt.zero ? GlassColors.danger : GlassColors.success),
                    ),
                  ],
                ),
              ),
            if (percent != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: GlassRadius.roundedPill,
                child: LinearProgressIndicator(
                  key: ValueKey('group-budget-${group.id}'),
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: GlassColors.secondarySurface,
                  color: percent >= 100 ? GlassColors.danger : GlassColors.accentSkyBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text('Đã chi $percent% ngân sách tháng', style: GlassTypography.bodySm()),
            ],
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final m in preview)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: GlassColors.secondarySurface,
                        child: Text(
                          m.displayName.isEmpty ? '?' : m.displayName[0].toUpperCase(),
                          style: GlassTypography.bodySm(color: GlassColors.textPrimary),
                        ),
                      ),
                    ),
                  if (extra > 0) Text('+$extra', style: GlassTypography.bodySm()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
