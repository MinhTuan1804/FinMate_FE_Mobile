import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class SharedGroupItem {
  final String id;
  final String name;
  final int memberCount;
  final BigInt totalSpendThisMonth;
  final String myRole;
  final IconData icon;

  const SharedGroupItem({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.totalSpendThisMonth,
    required this.myRole,
    required this.icon,
  });
}

/// Màn I1 - I7: Nhóm chi tiêu chung (Shared Groups Hub)
class GroupsHubScreen extends ConsumerStatefulWidget {
  const GroupsHubScreen({super.key});

  @override
  ConsumerState<GroupsHubScreen> createState() => _GroupsHubScreenState();
}

class _GroupsHubScreenState extends ConsumerState<GroupsHubScreen> {
  final List<SharedGroupItem> _groups = [
    SharedGroupItem(
      id: 'g1',
      name: 'Gia đình nhỏ',
      memberCount: 3,
      totalSpendThisMonth: BigInt.from(12450000),
      myRole: 'Trưởng nhóm',
      icon: LucideIcons.house,
    ),
    SharedGroupItem(
      id: 'g2',
      name: 'Chuyến đi Phú Quốc hè 2026',
      memberCount: 5,
      totalSpendThisMonth: BigInt.from(8200000),
      myRole: 'Thành viên',
      icon: LucideIcons.plane,
    ),
    SharedGroupItem(
      id: 'g3',
      name: 'Hội bạn thân Cà phê',
      memberCount: 4,
      totalSpendThisMonth: BigInt.from(1560000),
      myRole: 'Thành viên',
      icon: LucideIcons.coffee,
    ),
  ];

  void _createNewGroup() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo nhóm chi tiêu mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên nhóm (Gia đình, Bạn cùng phòng...)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _groups.add(
                    SharedGroupItem(
                      id: 'g-${DateTime.now().millisecondsSinceEpoch}',
                      name: nameController.text.trim(),
                      memberCount: 1,
                      totalSpendThisMonth: BigInt.zero,
                      myRole: 'Trưởng nhóm',
                      icon: LucideIcons.users,
                    ),
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo nhóm chi tiêu mới!')),
                );
              }
            },
            child: const Text('Tạo nhóm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhóm chi tiêu chung'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewGroup,
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('Tạo nhóm mới'),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Info
              ZenvestHeroDeck(
                peekBadgeText: 'GROUP',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUẢN LÝ QUỸ & CHIA TIỀN TỰ ĐỘNG',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Minh bạch mọi chi phí nhóm',
                        style: AppTypography.h1(context).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Theo dõi ai đã chi, ai cần trả bao nhiêu, chia đều hoặc chia theo tỷ lệ tự động.',
                        style: AppTypography.caption(context).copyWith(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('CÁC NHÓM ĐANG THAM GIA', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              for (final group in _groups) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LiquidGlassCard(
                    padding: const EdgeInsets.all(18),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đang mở chi tiết nhóm: ${group.name}')),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(group.icon, size: 22, color: AppColors.slateAction),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: AppTypography.body(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${group.memberCount} thành viên • Vai trò: ${group.myRole}',
                                style: AppTypography.caption(context).copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Đã chi tháng này: ${formatVnd(group.totalSpendThisMonth)}',
                                style: AppTypography.tabular(
                                  AppTypography.caption(context).copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 18),
                      ],
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
