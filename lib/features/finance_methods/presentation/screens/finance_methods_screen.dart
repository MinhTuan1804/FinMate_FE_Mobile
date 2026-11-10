import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';

String _roleLabel(String role) => switch (role) {
      'primary' => 'Chính',
      'supporting' => 'Bổ trợ',
      'both' => 'Chính hoặc bổ trợ',
      _ => role,
    };

String _levelLabel(String level) => switch (level) {
      'none' => 'Chưa có số',
      'ok' => 'Ổn',
      't1' => 'Nhắc nhẹ',
      't2' => 'Cảnh báo mạnh',
      'over' => 'Vượt hạn mức',
      _ => level,
    };

Color _levelColor(String level) => switch (level) {
      'over' => AppColors.danger,
      't2' => AppColors.danger,
      't1' => AppColors.warning,
      'ok' => AppColors.safe,
      _ => AppColors.secondary,
    };

/// Màn test toàn bộ nhóm API Cách quản lý tài chính (catalog, gợi ý, cách đang dùng, tham số,
/// ngưỡng cảnh báo, hũ, tiền khả dụng, gợi ý mục tiêu). Tạo gợi ý cần đã làm khảo sát trước
/// (nhóm Survey) — lỗi 422 ở đây là bình thường nếu chưa làm.
class FinanceMethodsScreen extends ConsumerWidget {
  const FinanceMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cách quản lý tài chính')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _RecommendationSection(),
          const SizedBox(height: AppSpacing.lg),
          _MyMethodsSection(),
          const SizedBox(height: AppSpacing.lg),
          _CatalogSection(),
          const SizedBox(height: AppSpacing.lg),
          _ThresholdsSection(),
          const SizedBox(height: AppSpacing.lg),
          _SpendableSection(),
          const SizedBox(height: AppSpacing.lg),
          _JarsSection(),
          const SizedBox(height: AppSpacing.lg),
          _GoalSuggestionsSection(),
        ],
      ),
    );
  }
}

Widget _sectionCard({required String title, required Widget child}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    ),
  );
}

class _RecommendationSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendationControllerProvider);
    final controller = ref.read(recommendationControllerProvider.notifier);

    Future<void> generate() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await controller.generate();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
      }
    }

    Future<void> skip(String id) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await controller.skip(id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
      }
    }

    return _sectionCard(
      title: 'Gợi ý phương pháp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            key: const ValueKey('method-generate-recommendation'),
            onPressed: generate,
            child: const Text('Tạo gợi ý mới'),
          ),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (e, __) => Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            data: (rec) {
              if (rec == null) {
                return Text('Chưa có gợi ý nào.', style: AppTypography.caption(context));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                key: const ValueKey('method-recommendation-result'),
                children: [
                  Text('Nguồn: ${rec.source == 'ai' ? 'AI' : 'Quy tắc'} · Trạng thái: ${rec.outcome}', style: AppTypography.caption(context)),
                  Text('Chính: ${rec.primary.method.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(rec.primary.reason, style: AppTypography.caption(context)),
                  if (rec.support != null) ...[
                    const SizedBox(height: 6),
                    Text('Bổ trợ: ${rec.support!.method.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(rec.support!.reason, style: AppTypography.caption(context)),
                  ],
                  if (rec.outcome == 'shown')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('method-skip-recommendation'),
                        onPressed: () => skip(rec.id),
                        child: const Text('Bỏ qua gợi ý này'),
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
}

class _CatalogSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(methodCatalogProvider);
    return _sectionCard(
      title: 'Danh mục cách quản lý',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(methodCatalogProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (methods) => Column(
          children: [
            for (final m in methods)
              Padding(
                key: ValueKey('method-catalog-${m.code}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m.name} (${_roleLabel(m.role)})', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(m.summary, style: AppTypography.caption(context)),
                        ],
                      ),
                    ),
                    if (m.canBePrimary)
                      TextButton(
                        key: ValueKey('method-choose-primary-${m.code}'),
                        onPressed: () => _choose(context, ref, m.code, 'primary'),
                        child: const Text('Chọn chính'),
                      ),
                    if (m.canBeSupport)
                      TextButton(
                        key: ValueKey('method-choose-supporting-${m.code}'),
                        onPressed: () => _choose(context, ref, m.code, 'supporting'),
                        child: const Text('Chọn bổ trợ'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, String code, String role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myMethodsControllerProvider.notifier).choose(methodCode: code, role: role);
      messenger.showSnackBar(const SnackBar(content: Text('Đã chọn cách quản lý.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }
}

class _MyMethodsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMethodsControllerProvider);
    return _sectionCard(
      title: 'Cách tôi đang dùng',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.read(myMethodsControllerProvider.notifier).load(), child: const Text('Thử lại')),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return Text('Chưa dùng cách quản lý nào.', style: AppTypography.caption(context));
          }
          return Column(
            children: [
              for (final um in list)
                Padding(
                  key: ValueKey('my-method-${um.id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${um.method.name} · ${_roleLabel(um.role)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            key: ValueKey('my-method-edit-params-${um.id}'),
                            onPressed: () => _editParams(context, ref, um),
                            child: const Text('Chỉnh tham số'),
                          ),
                          TextButton(
                            key: ValueKey('my-method-end-${um.id}'),
                            onPressed: () => ref.read(myMethodsControllerProvider.notifier).end(um.id),
                            child: const Text('Kết thúc'),
                          ),
                        ],
                      ),
                      Text(
                        'Hiệu lực: ${um.effective.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
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
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }
}

class _ThresholdsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ThresholdsSection> createState() => _ThresholdsSectionState();
}

class _ThresholdsSectionState extends ConsumerState<_ThresholdsSection> {
  final _t1Controller = TextEditingController();
  final _t2Controller = TextEditingController();

  @override
  void dispose() {
    _t1Controller.dispose();
    _t2Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t1 = int.tryParse(_t1Controller.text.trim());
    final t2 = int.tryParse(_t2Controller.text.trim());
    if (t1 == null || t2 == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alertThresholdsControllerProvider.notifier).setPersonal(t1Pct: t1, t2Pct: t2);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alertThresholdsControllerProvider.notifier).clearPersonal();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(alertThresholdsControllerProvider);
    return _sectionCard(
      title: 'Ngưỡng cảnh báo ngân sách',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.read(alertThresholdsControllerProvider.notifier).load(), child: const Text('Thử lại')),
          ],
        ),
        data: (t) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đang áp dụng: T1=${t.t1Pct}% · T2=${t.t2Pct}% (nguồn: ${t.source})',
              key: const ValueKey('threshold-effective'),
            ),
            if (t.methodName != null) Text('Theo cách: ${t.methodName}', style: AppTypography.caption(context)),
            Text('Mặc định hệ thống: T1=${t.systemDefault.t1Pct}% · T2=${t.systemDefault.t2Pct}%', style: AppTypography.caption(context)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('threshold-t1-input'),
                    controller: _t1Controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'T1 cá nhân (%)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('threshold-t2-input'),
                    controller: _t2Controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'T2 cá nhân (%)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                ElevatedButton(key: const ValueKey('threshold-save'), onPressed: _save, child: const Text('Lưu ngưỡng cá nhân')),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(key: const ValueKey('threshold-clear'), onPressed: _clear, child: const Text('Xóa, dùng mặc định')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendableSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spendableProvider);
    return _sectionCard(
      title: 'Tiền khả dụng tháng này',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(spendableProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.spendableCents == null ? 'Chưa khai thu nhập.' : 'Còn được chi: ${formatVnd(s.spendableCents!)}',
              key: const ValueKey('spendable-amount'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Thu nhập: ${s.incomeCents == null ? 'chưa khai' : formatVnd(s.incomeCents!)}', style: AppTypography.caption(context)),
            Text('Đã chi: ${formatVnd(s.spentCents)}', style: AppTypography.caption(context)),
            Text('Để dành cho mục tiêu: ${formatVnd(s.goalSetAsideCents)}', style: AppTypography.caption(context)),
            for (final g in s.goals)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${g.name}: cần ${formatVnd(g.requiredPerMonthCents)}/tháng, đã nạp ${formatVnd(g.depositedThisMonthCents)}',
                    style: AppTypography.caption(context)),
              ),
          ],
        ),
      ),
    );
  }
}

class _JarsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jarsProvider);
    return _sectionCard(
      title: 'Các hũ',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(jarsProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (sets) {
          if (sets.isEmpty) {
            return Text('Cách đang dùng không có khối hũ.', style: AppTypography.caption(context));
          }
          return Column(
            children: [
              for (final set in sets)
                Padding(
                  key: ValueKey('jar-set-${set.userMethodId}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(set.title ?? set.methodName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      for (final jar in set.jars)
                        Padding(
                          key: ValueKey('jar-${set.userMethodId}-${jar.key}'),
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Row(
                            children: [
                              Expanded(child: Text('${jar.label} (${jar.allocationPct}%)')),
                              Text(
                                jar.allocatedCents == null ? 'Chưa biết' : formatVnd(jar.allocatedCents!),
                                style: AppTypography.caption(context),
                              ),
                              const SizedBox(width: 8),
                              Text(_levelLabel(jar.level), style: TextStyle(color: _levelColor(jar.level), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalSuggestionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalSuggestionsProvider);
    return _sectionCard(
      title: 'Mẫu mục tiêu gợi ý',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(goalSuggestionsProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return Text('Chưa có mẫu mục tiêu phù hợp.', style: AppTypography.caption(context));
          }
          return Column(
            children: [
              for (final g in list)
                Padding(
                  key: ValueKey('goal-suggestion-${g.templateCode}'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(g.description, style: AppTypography.caption(context)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
