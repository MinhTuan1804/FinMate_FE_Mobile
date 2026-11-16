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
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';

enum _GroupFilter { all, family, other }

/// I1 — Danh sách nhóm (Stitch `i1_group_list`). Hero tổng chi tháng này cộng dồn mọi nhóm, không có
/// dòng "Cần thanh toán"/thẻ cấn trừ nợ AI (hệ thống thật là quỹ chung 1 sổ duy nhất, không phải chia
/// nợ từng khoản — xem quyết định phạm vi Luồng 8a). Loại nhóm chỉ 2 giá trị thật (Family/Other).
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  _GroupFilter _filter = _GroupFilter.all;

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
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
              ),
              icon: const Icon(LucideIcons.userPlus, size: 18),
              label: Text('Tạo nhóm mới', style: GlassTypography.buttonText()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<GroupEntity> groups) {
    final filtered = switch (_filter) {
      _GroupFilter.all => groups,
      _GroupFilter.family => groups.where((g) => g.type == GroupType.family).toList(),
      _GroupFilter.other => groups.where((g) => g.type == GroupType.other).toList(),
    };
    final familyCount = groups.where((g) => g.type == GroupType.family).length;
    final otherCount = groups.where((g) => g.type == GroupType.other).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        _HeroCard(groupCount: groups.length),
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
                selected: _filter == _GroupFilter.all,
                onTap: () => setState(() => _filter = _GroupFilter.all),
              ),
              const SizedBox(width: 8),
              GlassFilterChip(
                key: const ValueKey('group-filter-family'),
                label: 'Gia đình',
                count: familyCount,
                selected: _filter == _GroupFilter.family,
                onTap: () => setState(() => _filter = _GroupFilter.family),
              ),
              const SizedBox(width: 8),
              GlassFilterChip(
                key: const ValueKey('group-filter-other'),
                label: 'Khác',
                count: otherCount,
                selected: _filter == _GroupFilter.other,
                onTap: () => setState(() => _filter = _GroupFilter.other),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Nhóm đang tham gia', style: GlassTypography.headlineSm()),
        const SizedBox(height: 12),
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
      ],
    );
  }
}

class _HeroCard extends ConsumerWidget {
  final int groupCount;
  const _HeroCard({required this.groupCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final spendAsync = ref.watch(allGroupsMonthlySpendProvider);
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
          spendAsync.when(
            loading: () => Text('…', style: GlassTypography.displayHero()),
            error: (_, __) => Text('—', style: GlassTypography.displayHero()),
            data: (cents) => Text('${NumberFormat('#,###', 'vi_VN').format(cents.toInt())} ₫', style: GlassTypography.displayHero()),
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
    final fundAsync = ref.watch(groupPrimaryFundProvider(group.id));
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
                  child: Icon(groupTypeIcon(group.type), color: groupTypeColor(group.type), size: 20),
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
            fundAsync.maybeWhen(
              data: (fund) {
                if (fund == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quỹ chung hiện có', style: GlassTypography.bodySm()),
                      Text(
                        fund.formattedBalance,
                        style: GlassTypography.labelNumeric(color: fund.isNegative ? GlassColors.danger : GlassColors.success),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

