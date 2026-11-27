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
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_loading_spinner.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';

String _roleLabel(String role) => switch (role) {
  'primary' => 'Chính',
  'supporting' => 'Bổ trợ',
  'both' => 'Chính hoặc bổ trợ',
  _ => role,
};

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
const Set<String> _accumulativeJarKeys = {
  'long_term_pct',
  'financial_freedom_pct',
  'give_pct',
};

GlassProgressState _jarChipState(JarEntity jar) {
  if (jar.level == 'over' || jar.level == 't2') {
    return GlassProgressState.danger;
  }
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
  if (jar.remainingCents != null) {
    return 'Còn ${formatVnd(jar.remainingCents!)}';
  }
  return 'Ổn định';
}

JarSetEntity? _findJarSet(List<JarSetEntity> sets, String userMethodId) {
  for (final s in sets) {
    if (s.userMethodId == userMethodId) return s;
  }
  return null;
}

void _openEditSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => const _EditMethodsSheet(),
);

String _monthYear(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// B5 — Cách quản lý của tôi: phương pháp đang áp dụng (hero), chi tiết các hũ phân bổ (nếu có).
/// Chỉnh tham số/kết thúc cách đang dùng chuyển vào bottom sheet mở từ icon bút ở AppBar.
class MyMethodsScreen extends ConsumerWidget {
  const MyMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(
          context,
          title: 'Cách quản lý của tôi',
          actions: [
            IconButton(
              key: const ValueKey('go-home'),
              tooltip: 'Về trang chủ',
              icon: Icon(LucideIcons.house, color: GlassColors.slateAnchor),
              onPressed: () => context.go('/home'),
            ),
            IconButton(
              key: const ValueKey('open-financial-plan'),
              tooltip: 'Kế hoạch tháng',
              icon: Icon(
                LucideIcons.calendarRange,
                size: 20,
                color: GlassColors.slateAnchor,
              ),
              onPressed: () => context.push('/finance-methods/plan'),
            ),
            IconButton(
              key: const ValueKey('open-alert-thresholds'),
              tooltip: 'Ngưỡng cảnh báo',
              icon: Icon(
                LucideIcons.bellRing,
                size: 20,
                color: GlassColors.slateAnchor,
              ),
              onPressed: () =>
                  context.push('/finance-methods/alert-thresholds'),
            ),
            IconButton(
              key: const ValueKey('open-edit-methods'),
              tooltip: 'Chỉnh sửa cấu hình',
              icon: Icon(
                LucideIcons.pencil,
                size: 20,
                color: GlassColors.slateAnchor,
              ),
              onPressed: () => _openEditSheet(context),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeroSection(),
              const SizedBox(height: 16),
              _MethodBlocksSection(),
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
      loading: () => const GlassCard(level: 2, child: GlassLoadingSpinner()),
      error: (e, __) => GlassCard(
        level: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: GlassTypography.bodySm(color: GlassColors.danger),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(myMethodsControllerProvider.notifier).load(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return GlassCard(
            level: 2,
            child: Text(
              'Chưa dùng cách quản lý nào.',
              style: GlassTypography.bodyMd(),
            ),
          );
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
    final jarSet = jarsAsync.maybeWhen(
      data: (sets) => _findJarSet(sets, active.id),
      orElse: () => null,
    );
    final incomeCents = spendableAsync.maybeWhen(
      data: (s) => s.incomeCents,
      orElse: () => null,
    );

    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(17),
      borderRadius: GlassRadius.roundedCardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: GlassRadius.roundedPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: GlassColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Đang hoạt động từ ${_formatDate(active.startedAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: GlassTypography.labelCaps(
                            color: GlassColors.slateAnchor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_roleLabel(active.role), style: GlassTypography.labelCaps()),
            ],
          ),
          const SizedBox(height: 12),
          Text('Phương pháp đang áp dụng', style: GlassTypography.bodySm()),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(active.method.name, maxLines: 1, style: GlassTypography.headlineMd()),
          ),
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
                    Text(
                      'Căn cứ thu nhập hàng tháng',
                      style: GlassTypography.labelCaps(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incomeCents == null
                          ? 'Chưa khai thu nhập'
                          : formatVnd(incomeCents),
                      style: GlassTypography.displayHero(),
                    ),
                  ],
                ),
              ),
              if (jarSet != null && jarSet.jars.isNotEmpty)
                GlassBadge(
                  text: '${jarSet.jars.length} Hũ phân bổ',
                  color: GlassColors.slateAnchor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Giá trị tham số theo kiểu BE: percent → "%", minutes → "HH:mm" (phút trong ngày), còn lại là số nguyên.
String _paramValue(ParamEntity p, int v) {
  if (p.type == 'percent') return '$v%';
  if (p.type == 'minutes') {
    return '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
  }
  return '$v';
}

/// Suy nhóm ý nghĩa từ tên khóa cho tới khi BE trả `group`: *_pct là tỷ lệ chia, t1/t2 là ngưỡng cảnh báo, forecast_* là dự báo.
String _groupOfKey(String key) {
  if (key == 't1_pct' || key == 't2_pct') return 'Ngưỡng cảnh báo';
  if (key.startsWith('forecast')) return 'Dự báo hằng ngày';
  if (key.endsWith('_pct')) return 'Tỷ lệ chia';
  return 'Khác';
}

/// Các khối BE khai báo trong `homeLayout` của từng cách (trừ 'jars' do [_JarsSection] lo), theo đúng thứ tự BE,
/// để MỌI phương pháp đều có nội dung ở màn này, không chỉ "6 chiếc hũ". 'spendable' và 'goals' chỉ hiện một lần dù nhiều cách cùng khai báo.
class _MethodBlocksSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods =
        ref.watch(myMethodsControllerProvider).valueOrNull ??
        const <UserMethodEntity>[];
    if (methods.isEmpty) return const SizedBox.shrink();

    var spendableShown = false;
    var goalsShown = false;
    final cards = <Widget>[];
    for (final um in methods) {
      if (!um.method.available) cards.add(_UnavailableBanner(um: um));
      for (final block in um.method.effectiveLayout) {
        switch (block.type) {
          case 'spendable':
            if (!spendableShown) {
              spendableShown = true;
              cards.add(const _SpendableCard());
            }
          case 'goals':
            if (!goalsShown) {
              goalsShown = true;
              cards.add(const _GoalsCard());
            }
          case 'params':
            if (_blockParams(um.method, block).isNotEmpty) {
              cards.add(_ParamsCard(um: um, block: block));
            }
          case 'starter_steps':
            if (um.method.starterSteps.isNotEmpty) {
              cards.add(_StepsCard(um: um));
            }
        }
      }
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in cards)
          Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
      ],
    );
  }
}

/// Tham số của một khối 'params': đúng thứ tự `keys` BE khai báo; không có `keys` thì lấy tất cả.
List<ParamEntity> _blockParams(MethodEntity m, HomeBlockEntity block) {
  final keys = block.keys;
  if (keys == null) return m.params;
  final byKey = {for (final p in m.params) p.key: p};
  return [
    for (final k in keys)
      if (byKey[k] != null) byKey[k]!,
  ];
}

/// Cách đã bị admin tắt: người dùng vẫn dùng được, báo rõ và mời đổi.
class _UnavailableBanner extends StatelessWidget {
  final UserMethodEntity um;

  const _UnavailableBanner({required this.um});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: ValueKey('method-unavailable-${um.id}'),
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: GlassColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${um.method.name} đang tạm ngưng hỗ trợ. Bạn vẫn dùng được, nhưng nên đổi sang cách khác.',
              style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendableCard extends ConsumerWidget {
  const _SpendableCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spendableProvider);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GlassTypography.bodySm())),
          Text(
            value,
            style: GlassTypography.labelNumeric().copyWith(fontSize: 13),
          ),
        ],
      ),
    );

    return GlassCard(
      key: const ValueKey('method-block-spendable'),
      padding: const EdgeInsets.all(17),
      child: async.when(
        loading: () => const GlassLoadingSpinner(),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: GlassTypography.bodySm(color: GlassColors.danger),
            ),
            TextButton(
              onPressed: () => ref.invalidate(spendableProvider),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TIỀN KHẢ DỤNG THÁNG NÀY', style: GlassTypography.labelCaps()),
            const SizedBox(height: 4),
            Text(
              s.spendableCents == null
                  ? 'Chưa khai thu nhập'
                  : formatVnd(s.spendableCents!),
              style: GlassTypography.displayHero().copyWith(
                fontSize: s.spendableCents == null ? 20 : 30,
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: GlassColors.glassBorder),
            if (s.incomeCents != null)
              row('Thu nhập', formatVnd(s.incomeCents!)),
            row('Đã chi', formatVnd(s.spentCents)),
            row('Đặt riêng cho mục tiêu', formatVnd(s.goalSetAsideCents)),
          ],
        ),
      ),
    );
  }
}

/// Khối 'goals': tiến độ nạp các mục tiêu tháng này (từ /me/spendable) và mẫu mục tiêu gợi ý (từ /me/goal-suggestions).
class _GoalsCard extends ConsumerWidget {
  const _GoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals =
        ref.watch(spendableProvider).valueOrNull?.goals ??
        const <SpendableGoalEntity>[];
    final suggestions =
        ref.watch(goalSuggestionsProvider).valueOrNull ??
        const <GoalSuggestionEntity>[];
    return GlassCard(
      key: const ValueKey('method-block-goals'),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Mục tiêu của bạn',
              style: GlassTypography.headlineSm(),
            ),
          ),
          if (goals.isEmpty && suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Chưa có mục tiêu nào.',
                style: GlassTypography.bodyMd(),
              ),
            ),
          for (final g in goals)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      g.name,
                      style: GlassTypography.bodyMd(
                        color: GlassColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${formatVnd(g.depositedThisMonthCents)} / ${formatVnd(g.requiredPerMonthCents)}',
                    style: GlassTypography.labelNumeric().copyWith(
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('GỢI Ý MỤC TIÊU', style: GlassTypography.labelCaps()),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: GlassTypography.bodyMd(
                        color: GlassColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(s.description, style: GlassTypography.bodySm()),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Khối 'params': các tham số đang áp dụng. `display == 'allocation'` (hoặc nhóm tỷ lệ chia khi BE không khai báo `keys`)
/// hiện thanh tỷ lệ và tổng, báo khi chưa đủ 100%. BE không bắt buộc tổng 100% nên app tự cảnh báo.
class _ParamsCard extends StatelessWidget {
  final UserMethodEntity um;
  final HomeBlockEntity block;

  const _ParamsCard({required this.um, required this.block});

  @override
  Widget build(BuildContext context) {
    final params = _blockParams(um.method, block);
    // Không có keys: tự nhóm theo ý nghĩa; có keys: một nhóm duy nhất theo tiêu đề BE.
    final sections = <String, List<ParamEntity>>{};
    if (block.keys == null) {
      for (final p in params) {
        sections.putIfAbsent(_groupOfKey(p.key), () => []).add(p);
      }
    } else {
      sections[block.title ?? 'Tham số đang áp dụng'] = params;
    }
    return GlassCard(
      key: ValueKey('method-block-params-${um.id}-${block.title ?? 'all'}'),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${um.method.name} · ${_roleLabel(um.role)}',
            style: GlassTypography.bodySm(),
          ),
          for (final e in sections.entries) ...[
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: Text(e.key, style: GlassTypography.headlineSm()),
            ),
            const SizedBox(height: 4),
            _section(
              e.value,
              allocation:
                  block.display == 'allocation' ||
                  (block.keys == null && e.key == 'Tỷ lệ chia'),
            ),
          ],
        ],
      ),
    );
  }

  int _value(ParamEntity p) => um.effective[p.key] ?? p.defaultValue;

  Widget _section(List<ParamEntity> params, {required bool allocation}) {
    final percentParams = params.where((p) => p.type == 'percent').toList();
    final showTotal = allocation && percentParams.isNotEmpty;
    final total = percentParams.fold<int>(0, (sum, p) => sum + _value(p));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in params)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.label,
                        style: GlassTypography.bodyMd(
                          color: GlassColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _paramValue(p, _value(p)),
                      style: GlassTypography.labelNumeric().copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (allocation && p.type == 'percent') ...[
                  const SizedBox(height: 6),
                  Semantics(
                    label: '${p.label}: ${_value(p)}%',
                    excludeSemantics: true,
                    child: GlassProgressBar(
                      percent: _value(p).toDouble(),
                      height: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (showTotal) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng tỷ lệ',
                  style: GlassTypography.bodyMd(
                    color: GlassColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              GlassBadge(
                key: const ValueKey('method-allocation-total'),
                text: total == 100
                    ? 'Đủ 100%'
                    : (total < 100
                          ? '$total% · còn ${100 - total}% chưa phân bổ'
                          : '$total% · vượt ${total - 100}%'),
                color: total == 100 ? GlassColors.success : GlassColors.warning,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepsCard extends StatelessWidget {
  final UserMethodEntity um;

  const _StepsCard({required this.um});

  @override
  Widget build(BuildContext context) {
    final m = um.method;
    final steps = m.starterSteps;
    return GlassCard(
      key: ValueKey('method-block-${um.id}'),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${m.name} · ${_roleLabel(um.role)}',
            style: GlassTypography.headlineSm(),
          ),
          if (m.whyText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              m.whyText,
              style: GlassTypography.bodySm(color: GlassColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Text('BƯỚC BẮT ĐẦU', style: GlassTypography.labelCaps()),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GlassColors.accentSkyBlue.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: GlassTypography.labelCaps(
                        color: GlassColors.slateAnchor,
                      ).copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: GlassTypography.bodyMd(
                        color: GlassColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
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
      loading: () => const GlassCard(child: GlassLoadingSpinner()),
      error: (e, __) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage(e),
              style: GlassTypography.bodySm(color: GlassColors.danger),
            ),
            TextButton(
              onPressed: () => ref.invalidate(jarsProvider),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (sets) {
        if (sets.isEmpty || sets.every((s) => s.jars.isEmpty)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassPrimaryButton(
                key: const ValueKey('adjust-method-params'),
                label: 'Điều chỉnh tham số',
                icon: LucideIcons.slidersHorizontal,
                onPressed: () => _openEditSheet(context),
              ),
              const SizedBox(height: 12),
              GlassSecondaryButton(
                key: const ValueKey('switch-method'),
                label: 'Đổi phương pháp khác',
                onPressed: () => context.push('/finance-methods'),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  set.title ?? set.methodName,
                                  style: GlassTypography.headlineSm(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tháng ${_monthYear(set.periodStart)}',
                              style: GlassTypography.bodySm(),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < set.jars.length; i++)
                        Padding(
                          key: ValueKey(
                            'jar-${set.userMethodId}-${set.jars[i].key}',
                          ),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _JarCard(
                            userMethodId: set.userMethodId,
                            jar: set.jars[i],
                            // Figma: 3 hũ đầu là thẻ đầy đủ, các hũ còn lại dạng gọn.
                            compact: i >= 3,
                          ),
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
            GlassPrimaryButton(
              key: const ValueKey('adjust-method-params'),
              label: 'Điều chỉnh tỷ lệ %',
              icon: LucideIcons.slidersHorizontal,
              onPressed: () => _openEditSheet(context),
            ),
            const SizedBox(height: 12),
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

  /// Dạng gọn (icon + % ở trên, số tiền ở dưới) như 3 hũ cuối trong Figma.
  final bool compact;

  const _JarCard({
    required this.userMethodId,
    required this.jar,
    this.compact = false,
  });

  void _open(BuildContext context) => context.push(
    '/finance-methods/jar-detail',
    extra: {'userMethodId': userMethodId, 'jarKey': jar.key},
  );

  @override
  Widget build(BuildContext context) {
    final percent =
        jar.allocatedCents == null || jar.allocatedCents == BigInt.zero
        ? 0.0
        : (jar.spentCents.toDouble() / jar.allocatedCents!.toDouble() * 100);
    final chipState = _jarChipState(jar);
    final warn = jar.level == 'over' || jar.level == 't2';
    final subtitle = jar.categories.map((c) => c.name).join(', ');
    final borderColor = warn
        ? GlassColors.accentDustyRose.withValues(alpha: 0.6)
        : null;

    final icon = Container(
      width: compact ? 32 : 40,
      height: compact ? 32 : 40,
      decoration: BoxDecoration(
        color: (warn ? GlassColors.accentDustyRose : GlassColors.accentSkyBlue)
            .withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(compact ? 16 : 16),
      ),
      child: Icon(
        _jarIcon(jar.key),
        size: compact ? 16 : 20,
        color: warn ? GlassColors.danger : GlassColors.slateAnchor,
      ),
    );

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: borderColor == null ? null : Border.all(color: borderColor),
          ),
          child: GlassCard(
            padding: EdgeInsets.all(compact ? 15 : 17),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            child: compact
                ? _compactBody(icon, subtitle, percent, chipState)
                : _fullBody(icon, subtitle, percent, chipState),
          ),
        ),
      ),
    );
  }

  Widget _fullBody(
    Widget icon,
    String subtitle,
    double percent,
    GlassProgressState chipState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          jar.label,
                          style: GlassTypography.bodyLg(
                            color: GlassColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GlassBadge(text: '${jar.allocationPct}%'),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: GlassTypography.bodySm(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatVnd(jar.spentCents),
                  style: GlassTypography.labelNumeric(
                    color: _chipColor(chipState),
                  ),
                ),
                Text(
                  jar.allocatedCents == null
                      ? 'Chưa biết'
                      : '/ ${formatVnd(jar.allocatedCents!)}',
                  style: GlassTypography.bodySm(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        GlassProgressBar(percent: percent, state: chipState, height: 8),
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
    );
  }

  Widget _compactBody(
    Widget icon,
    String subtitle,
    double percent,
    GlassProgressState chipState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            icon,
            GlassBadge(text: '${jar.allocationPct}%'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          jar.label,
          style: GlassTypography.bodyLg(
            color: GlassColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: GlassTypography.bodySm(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 9),
        Divider(height: 1, color: GlassColors.glassBorder),
        const SizedBox(height: 9),
        Text(formatVnd(jar.spentCents), style: GlassTypography.labelNumeric()),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                jar.allocatedCents == null
                    ? 'Chưa biết ngân sách'
                    : 'Ngân sách: ${formatVnd(jar.allocatedCents!)}',
                style: GlassTypography.bodySm(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${jar.usedPct ?? percent.round()}%',
              style: GlassTypography.labelNumeric(
                color: _chipColor(chipState),
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

/// Giờ:phút (phút trong ngày) → "HH:mm".
String _hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Đọc nội dung ô nhập theo kiểu tham số của BE. Trả (giá trị, lỗi); ô trống = null, không lỗi (về mặc định).
/// 'minutes' nhập dạng HH:mm nhưng vẫn gửi BE bằng phút.
(int?, String?) _parseParamInput(ParamEntity p, String raw) {
  final text = raw.trim();
  if (text.isEmpty) return (null, null);
  int? v;
  if (p.type == 'minutes') {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (m == null) return (null, 'Nhập giờ theo dạng HH:mm, ví dụ 22:00.');
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    if (h > 23 || mm > 59) return (null, 'Giờ hợp lệ từ 00:00 đến 23:59.');
    v = h * 60 + mm;
  } else {
    v = int.tryParse(text);
    if (v == null) return (null, 'Nhập một số nguyên.');
  }
  if (v < p.min || v > p.max) {
    return (
      null,
      'Chỉ nhận từ ${_paramValue(p, p.min)} đến ${_paramValue(p, p.max)}.',
    );
  }
  return (v, null);
}

/// Khung "Quản lý cách đang dùng": mỗi cách là một thẻ (tên, huy hiệu Chính/Bổ trợ, vài thông số chính, hai nút).
class _EditMethodsSheet extends ConsumerWidget {
  const _EditMethodsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMethodsControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        // SizedBox: bottom sheet cấp ràng buộc lỏng nên thẻ kính tự co theo nội dung (lệch, hẹp)
        child: SizedBox(
          width: double.infinity,
          child: GlassCard(
            level: 3,
            padding: const EdgeInsets.all(17),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Quản lý cách đang dùng',
                          style: GlassTypography.headlineSm(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: GlassColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: async.when(
                    loading: () => const GlassLoadingSpinner(),
                    error: (e, __) => Text(
                      errorMessage(e),
                      style: GlassTypography.bodySm(color: GlassColors.danger),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return Text(
                          'Chưa dùng cách quản lý nào.',
                          style: GlassTypography.bodyMd(),
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final um in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MethodManageCard(um: um),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodManageCard extends ConsumerWidget {
  final UserMethodEntity um;

  const _MethodManageCard({required this.um});

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: 'Kết thúc cách này?',
        actions: [
          GlassGhostButton(
            label: 'Giữ lại',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          _DangerButton(
            key: const ValueKey('my-method-end-confirm'),
            label: 'Kết thúc',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
        child: Text(
          'Bạn sẽ ngừng dùng "${um.method.name}". Các tham số đã chỉnh sẽ không còn áp dụng.',
          style: GlassTypography.bodyMd(),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(myMethodsControllerProvider.notifier).end(um.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage(e)),
          backgroundColor: GlassColors.danger,
        ),
      );
    }
  }

  Future<void> _editParams(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ParamsDialog(
        um: um,
        onSave: (changes) => ref
            .read(myMethodsControllerProvider.notifier)
            .updateParams(um.id, changes),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Vài thông số chính, nhãn lấy từ định nghĩa tham số của BE (không viết cứng tên).
    final shown = um.method.params.take(4).toList();
    return Container(
      key: ValueKey('my-method-${um.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  um.method.name,
                  style: GlassTypography.bodyLg().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassBadge(text: _roleLabel(um.role)),
            ],
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.label,
                        style: GlassTypography.bodySm(
                          color: GlassColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _paramValue(p, um.effective[p.key] ?? p.defaultValue),
                      style: GlassTypography.labelNumeric().copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GlassSecondaryButton(
                  key: ValueKey('my-method-edit-params-${um.id}'),
                  label: 'Chỉnh tham số',
                  onPressed: () => _editParams(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DangerButton(
                  key: ValueKey('my-method-end-${um.id}'),
                  label: 'Kết thúc',
                  onPressed: () => _confirmEnd(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút viền đỏ cho hành động nguy hiểm, cùng kích thước nút phụ.
class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: GlassColors.danger,
          side: BorderSide(color: GlassColors.danger.withValues(alpha: 0.5)),
          shape: const RoundedRectangleBorder(
            borderRadius: GlassRadius.roundedPill,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GlassTypography.buttonText(color: GlassColors.danger),
        ),
      ),
    );
  }
}

/// Hộp thoại kính dùng chung cho hai hành động của khung quản lý (xác nhận kết thúc, chỉnh tham số).
class _GlassDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const _GlassDialog({
    required this.title,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        level: 3,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: GlassTypography.headlineSm()),
            ),
            const SizedBox(height: 12),
            Flexible(child: child),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại "Chỉnh tham số": ô nhóm theo ý nghĩa, nhãn đầy đủ, đơn vị cuối ô, gợi ý khoảng cho phép, tổng tỷ lệ,
/// lỗi (cục bộ lẫn của BE) hiện ngay trong hộp. Ô trống = về mặc định.
class _ParamsDialog extends StatefulWidget {
  final UserMethodEntity um;
  final Future<void> Function(Map<String, int?> changes) onSave;

  const _ParamsDialog({required this.um, required this.onSave});

  @override
  State<_ParamsDialog> createState() => _ParamsDialogState();
}

class _ParamsDialogState extends State<_ParamsDialog> {
  late final List<ParamEntity> _editable = widget.um.method.params
      .where((p) => p.userEditable)
      .toList();
  late final Map<String, TextEditingController> _controllers = {
    for (final p in _editable)
      p.key: TextEditingController(text: _initialText(p)),
  };
  final Map<String, String> _fieldErrors = {};
  String? _serverError;
  bool _saving = false;

  String _initialText(ParamEntity p) {
    final v = widget.um.effective[p.key] ?? p.defaultValue;
    return p.type == 'minutes' ? _hhmm(v) : '$v';
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Giá trị đang nhập; ô trống hoặc sai thì tính theo mặc định của BE.
  int _current(ParamEntity p) =>
      _parseParamInput(p, _controllers[p.key]!.text).$1 ?? p.defaultValue;

  Future<void> _save() async {
    final changes = <String, int?>{};
    final errors = <String, String>{};
    for (final p in _editable) {
      final (v, err) = _parseParamInput(p, _controllers[p.key]!.text);
      if (err != null) errors[p.key] = err;
      changes[p.key] = v;
    }
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _serverError = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(changes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = errorMessage(e);
        });
      }
    }
  }

  Widget _field(ParamEntity p) {
    final isMinutes = p.type == 'minutes';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nhãn nằm trên khung (không đè lên viền) và đủ đậm để đọc
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              p.label,
              style: GlassTypography.bodyMd(
                color: GlassColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextField(
            key: ValueKey('param-field-${p.key}'),
            controller: _controllers[p.key],
            keyboardType: isMinutes
                ? TextInputType.datetime
                : TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: GlassTypography.bodyLg(),
            decoration: InputDecoration(
              semanticCounterText: p.label,
              helperText:
                  'Từ ${_paramValue(p, p.min)} đến ${_paramValue(p, p.max)}. Để trống = mặc định (${_paramValue(p, p.defaultValue)}).',
              helperStyle: GlassTypography.bodySm(
                color: GlassColors.textSecondary,
              ),
              helperMaxLines: 2,
              errorText: _fieldErrors[p.key],
              errorMaxLines: 2,
              suffixText: p.type == 'percent' ? '%' : null,
              hintText: isMinutes ? 'HH:mm' : null,
              filled: true,
              fillColor: GlassColors.fieldFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: GlassColors.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: GlassColors.fieldBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ParamEntity>>{};
    for (final p in _editable) {
      groups.putIfAbsent(_groupOfKey(p.key), () => []).add(p);
    }
    return _GlassDialog(
      title: 'Chỉnh tham số',
      actions: [
        GlassGhostButton(
          label: 'Hủy',
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        GlassPrimaryButton(
          key: const ValueKey('param-dialog-save'),
          label: 'Lưu',
          loading: _saving,
          onPressed: _save,
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.um.method.name, style: GlassTypography.bodySm()),
            for (final e in groups.entries) ...[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  e.key,
                  style: GlassTypography.bodyLg().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final p in e.value) _field(p),
              if (e.key == 'Tỷ lệ chia') _totalLine(e.value),
            ],
            if (_serverError != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('param-server-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlassColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.circleAlert,
                      size: 16,
                      color: GlassColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverError!,
                        style: GlassTypography.bodySm(
                          color: GlassColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _totalLine(List<ParamEntity> group) {
    final percents = group.where((p) => p.type == 'percent').toList();
    if (percents.isEmpty) return const SizedBox.shrink();
    final total = percents.fold<int>(0, (s, p) => s + _current(p));
    final ok = total == 100;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tổng đang nhập',
              style: GlassTypography.bodyMd(
                color: GlassColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          GlassBadge(
            key: const ValueKey('param-total'),
            text: ok
                ? 'Đủ 100%'
                : (total < 100
                      ? '$total% · chưa đủ 100%'
                      : '$total% · vượt 100%'),
            color: ok ? GlassColors.success : GlassColors.warning,
          ),
        ],
      ),
    );
  }
}
