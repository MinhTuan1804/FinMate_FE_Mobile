import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';

String _roleLabel(String role) => switch (role) {
      'primary' => 'Chính',
      'supporting' => 'Bổ trợ',
      'both' => 'Chính hoặc bổ trợ',
      _ => role,
    };

String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// Khóa hũ cố định của phương pháp "6 chiếc hũ" (FinanceMethodSeeder.SixJarsLayout ở BE) — đây
// là phương pháp duy nhất có khối jars nên map icon theo đúng 6 key này là đủ, không cần tổng quát hơn.
const Map<String, IconData> _jarIcons = {
  'necessities_pct': LucideIcons.shoppingBasket,
  'education_pct': LucideIcons.graduationCap,
  'play_pct': LucideIcons.coffee,
  'financial_freedom_pct': LucideIcons.trendingUp,
  'long_term_pct': LucideIcons.piggyBank,
  'give_pct': LucideIcons.heartHandshake,
};

IconData _jarIcon(String key) => _jarIcons[key] ?? LucideIcons.wallet;

// Hũ tích luỹ (không phải hũ chi tiêu): dùng hết 100% phân bổ là đạt mục tiêu, không phải cảnh báo.
const Set<String> _accumulativeJarKeys = {'long_term_pct', 'financial_freedom_pct', 'give_pct'};

GlassProgressState _jarChipState(JarEntity jar) {
  if (jar.level == 'over' || jar.level == 't2') return GlassProgressState.danger;
  if (jar.level == 't1') return GlassProgressState.warning;
  return GlassProgressState.success;
}

Color _chipColor(GlassProgressState state) => switch (state) {
      GlassProgressState.danger => GlassColors.danger,
      GlassProgressState.warning => GlassColors.warning,
      GlassProgressState.success => GlassColors.success,
      GlassProgressState.normal => GlassColors.textMuted,
    };

String _jarChipLabel(JarEntity jar) {
  if (jar.level == 'over') return 'Vượt hạn mức';
  if (jar.level == 't2') return 'Sát hạn mức ${jar.usedPct ?? 0}%';
  if (jar.level == 't1') return 'Gần hạn mức ${jar.usedPct ?? 0}%';
  if (_accumulativeJarKeys.contains(jar.key) && (jar.usedPct ?? 0) >= 100) {
    return 'Đạt ${jar.usedPct}% mục tiêu';
  }
  if (jar.remainingCents != null) return 'Còn ${formatVnd(jar.remainingCents!)}';
  return 'Ổn định';
}

JarSetEntity? _findJarSet(List<JarSetEntity> sets, String userMethodId) {
  for (final s in sets) {
    if (s.userMethodId == userMethodId) return s;
  }
  return null;
}

/// B5 — Cách quản lý của tôi: phương pháp đang áp dụng (hero), chi tiết các hũ phân bổ (nếu có).
/// Chỉnh tham số/kết thúc cách đang dùng chuyển vào bottom sheet mở từ icon bút ở AppBar.
class MyMethodsScreen extends ConsumerWidget {
  const MyMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Cách quản lý của tôi', style: GlassTypography.headlineMd()),
          actions: [
            IconButton(
              key: const ValueKey('open-alert-thresholds'),
              tooltip: 'Ngưỡng cảnh báo',
              icon: const Icon(LucideIcons.bellRing, color: GlassColors.slateAnchor),
              onPressed: () => context.push('/finance-methods/alert-thresholds'),
            ),
            IconButton(
              key: const ValueKey('open-edit-methods'),
              tooltip: 'Chỉnh sửa cấu hình',
              icon: const Icon(LucideIcons.pencil, color: GlassColors.slateAnchor),
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const _EditMethodsSheet(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _HeroSection(),
              const SizedBox(height: 16),
              _JarsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMethodsControllerProvider);
    return async.when(
      loading: () => GlassCard(level: 2, child: const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
      error: (e, __) => GlassCard(
        level: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
            TextButton(onPressed: () => ref.read(myMethodsControllerProvider.notifier).load(), child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return GlassCard(level: 2, child: Text('Chưa dùng cách quản lý nào.', style: GlassTypography.bodyMd()));
        }
        UserMethodEntity active = list.first;
        for (final um in list) {
          if (um.isPrimary) {
            active = um;
            break;
          }
        }
        return _ActiveMethodHero(active: active);
      },
    );
  }
}

class _ActiveMethodHero extends ConsumerWidget {
  final UserMethodEntity active;

  const _ActiveMethodHero({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jarsAsync = ref.watch(jarsProvider);
    final spendableAsync = ref.watch(spendableProvider);
    final jarSet = jarsAsync.maybeWhen(data: (sets) => _findJarSet(sets, active.id), orElse: () => null);
    final incomeCents = spendableAsync.maybeWhen(data: (s) => s.incomeCents, orElse: () => null);

    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: GlassRadius.roundedPill),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: GlassColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      'Đang hoạt động từ ${_formatDate(active.startedAt)}',
                      style: GlassTypography.labelCaps(color: GlassColors.slateAnchor),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(_roleLabel(active.role), style: GlassTypography.labelCaps()),
            ],
          ),
          const SizedBox(height: 12),
          Text('Phương pháp đang áp dụng', style: GlassTypography.bodySm()),
          const SizedBox(height: 2),
          Text(active.method.name, style: GlassTypography.headlineMd()),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Căn cứ thu nhập hàng tháng', style: GlassTypography.labelCaps()),
                    const SizedBox(height: 4),
                    Text(
                      incomeCents == null ? 'Chưa khai thu nhập' : formatVnd(incomeCents),
                      style: GlassTypography.displayHero(),
                    ),
                  ],
                ),
              ),
              if (jarSet != null && jarSet.jars.isNotEmpty)
                GlassBadge(text: '${jarSet.jars.length} Hũ phân bổ', color: GlassColors.slateAnchor),
            ],
          ),
        ],
      ),
    );
  }
}

class _JarsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jarsProvider);
    return async.when(
      loading: () => GlassCard(child: const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
      error: (e, __) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
            TextButton(onPressed: () => ref.invalidate(jarsProvider), child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (sets) {
        if (sets.isEmpty || sets.every((s) => s.jars.isEmpty)) {
          return Column(
            children: [
              GlassCard(child: Text('Cách đang dùng không có khối hũ.', style: GlassTypography.bodyMd())),
              const SizedBox(height: 16),
              GlassSecondaryButton(
                key: const ValueKey('switch-method'),
                label: 'Đổi phương pháp khác',
                onPressed: () => context.push('/finance-methods'),
              ),
            ],
          );
        }
        return Column(
          children: [
            for (final set in sets)
              if (set.jars.isNotEmpty)
                Padding(
                  key: ValueKey('jar-set-${set.userMethodId}'),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(set.title ?? set.methodName, style: GlassTypography.headlineSm()),
                      ),
                      for (final jar in set.jars)
                        Padding(
                          key: ValueKey('jar-${set.userMethodId}-${jar.key}'),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _JarCard(userMethodId: set.userMethodId, jar: jar),
                        ),
                    ],
                  ),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Nguyên lý 6 Chiếc Hũ được T. Harv Eker chuẩn hoá cho tự chủ tài chính.',
                textAlign: TextAlign.center,
                style: GlassTypography.bodySm(),
              ),
            ),
            const SizedBox(height: 8),
            GlassSecondaryButton(
              key: const ValueKey('switch-method'),
              label: 'Đổi phương pháp khác',
              onPressed: () => context.push('/finance-methods'),
            ),
          ],
        );
      },
    );
  }
}

class _JarCard extends StatelessWidget {
  final String userMethodId;
  final JarEntity jar;

  const _JarCard({required this.userMethodId, required this.jar});

  @override
  Widget build(BuildContext context) {
    final percent = jar.allocatedCents == null || jar.allocatedCents == BigInt.zero
        ? 0.0
        : (jar.spentCents.toDouble() / jar.allocatedCents!.toDouble() * 100);
    final chipState = _jarChipState(jar);

    return GestureDetector(
      onTap: () => context.push(
        '/finance-methods/jar-detail',
        extra: {'userMethodId': userMethodId, 'jarKey': jar.key},
      ),
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: GlassColors.accentSkyBlue.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(_jarIcon(jar.key), size: 20, color: GlassColors.slateAnchor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          jar.label,
                          style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassBadge(text: '${jar.allocationPct}%'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatVnd(jar.spentCents), style: GlassTypography.labelNumeric()),
                    Text(
                      jar.allocatedCents == null ? 'Chưa biết' : '/ ${formatVnd(jar.allocatedCents!)}',
                      style: GlassTypography.bodySm(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassProgressBar(percent: percent, state: chipState),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Tiến độ chi tiêu: ${jar.usedPct ?? percent.round()}%',
                    style: GlassTypography.bodySm(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GlassBadge(text: _jarChipLabel(jar), color: _chipColor(chipState)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMethodsSheet extends ConsumerWidget {
  const _EditMethodsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMethodsControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: GlassCard(
          level: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quản lý cách đang dùng', style: GlassTypography.headlineSm()),
              const SizedBox(height: 12),
              async.when(
                loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                data: (list) {
                  if (list.isEmpty) {
                    return Text('Chưa dùng cách quản lý nào.', style: GlassTypography.bodyMd());
                  }
                  return Column(
                    children: [
                      for (final um in list)
                        Padding(
                          key: ValueKey('my-method-${um.id}'),
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${um.method.name} · ${_roleLabel(um.role)}',
                                style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Hiệu lực: ${um.effective.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                                style: GlassTypography.bodySm(),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  TextButton(
                                    key: ValueKey('my-method-edit-params-${um.id}'),
                                    onPressed: () => _editParams(context, ref, um),
                                    child: const Text('Chỉnh tham số'),
                                  ),
                                  TextButton(
                                    key: ValueKey('my-method-end-${um.id}'),
                                    onPressed: () => ref.read(myMethodsControllerProvider.notifier).end(um.id),
                                    child: Text('Kết thúc', style: GlassTypography.bodyMd(color: GlassColors.danger)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editParams(BuildContext context, WidgetRef ref, UserMethodEntity um) async {
    final editable = um.method.params.where((p) => p.userEditable).toList();
    final controllers = {for (final p in editable) p.key: TextEditingController(text: '${um.effective[p.key] ?? p.defaultValue}')};
    final changes = await showDialog<Map<String, int?>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh tham số'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in editable)
              TextField(
                key: ValueKey('param-field-${p.key}'),
                controller: controllers[p.key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '${p.label} (${p.min}–${p.max})'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          TextButton(
            key: const ValueKey('param-dialog-save'),
            onPressed: () => Navigator.pop(dialogContext, {for (final p in editable) p.key: int.tryParse(controllers[p.key]!.text.trim())}),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    // Dialog còn đang chạy animation thoát vài khung hình sau khi showDialog trả về kết quả;
    // dispose ngay sẽ làm TextField bên trong dùng controller đã dispose. Lùi sau khung hình hiện tại.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
    if (changes == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myMethodsControllerProvider.notifier).updateParams(um.id, changes);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }
}
