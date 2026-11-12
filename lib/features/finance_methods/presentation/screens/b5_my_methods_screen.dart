import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_jar_progress_card.dart';

String _roleLabel(String role) => switch (role) {
      'primary' => 'Chính',
      'supporting' => 'Bổ trợ',
      'both' => 'Chính hoặc bổ trợ',
      _ => role,
    };

/// B5 — Cách quản lý của tôi: các phương pháp đang dùng, hũ phân bổ (nếu có), tiền khả dụng
/// tháng này. Tap vào hũ để xem chi tiết (B6).
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
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _MyMethodsSection(),
              const SizedBox(height: 16),
              _SpendableSection(),
              const SizedBox(height: 16),
              _JarsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyMethodsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMethodsControllerProvider);
    return GlassCard(
      level: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cách tôi đang dùng', style: GlassTypography.headlineSm()),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                TextButton(onPressed: () => ref.read(myMethodsControllerProvider.notifier).load(), child: const Text('Thử lại')),
              ],
            ),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${um.method.name} · ${_roleLabel(um.role)}',
                                  style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
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
                          Text(
                            'Hiệu lực: ${um.effective.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                            style: GlassTypography.bodySm(),
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

class _SpendableSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spendableProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tiền khả dụng tháng này', style: GlassTypography.headlineSm()),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                TextButton(onPressed: () => ref.invalidate(spendableProvider), child: const Text('Thử lại')),
              ],
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.spendableCents == null ? 'Chưa khai thu nhập.' : 'Còn được chi: ${formatVnd(s.spendableCents!)}',
                  key: const ValueKey('spendable-amount'),
                  style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                Text('Thu nhập: ${s.incomeCents == null ? 'chưa khai' : formatVnd(s.incomeCents!)}', style: GlassTypography.bodySm()),
                Text('Đã chi: ${formatVnd(s.spentCents)}', style: GlassTypography.bodySm()),
                Text('Để dành cho mục tiêu: ${formatVnd(s.goalSetAsideCents)}', style: GlassTypography.bodySm()),
                for (final g in s.goals)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${g.name}: cần ${formatVnd(g.requiredPerMonthCents)}/tháng, đã nạp ${formatVnd(g.depositedThisMonthCents)}',
                      style: GlassTypography.bodySm(),
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
        if (sets.isEmpty) {
          return GlassCard(child: Text('Cách đang dùng không có khối hũ.', style: GlassTypography.bodyMd()));
        }
        return Column(
          children: [
            for (final set in sets)
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
                        child: GlassJarProgressCard(
                          label: jar.label,
                          icon: LucideIcons.wallet,
                          allocationPct: jar.allocationPct,
                          allocatedCents: jar.allocatedCents,
                          spentCents: jar.spentCents,
                          level: jar.level,
                          onTap: () => context.push(
                            '/finance-methods/jar-detail',
                            extra: {'userMethodId': set.userMethodId, 'jarKey': jar.key},
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
