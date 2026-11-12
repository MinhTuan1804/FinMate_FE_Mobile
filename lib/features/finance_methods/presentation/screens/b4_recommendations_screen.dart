import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

String _roleLabel(String role) => switch (role) {
      'primary' => 'Chính',
      'supporting' => 'Bổ trợ',
      'both' => 'Chính hoặc bổ trợ',
      _ => role,
    };

/// B4 — Gợi ý phương pháp quản lý tài chính: gợi ý AI/quy tắc + danh mục để tự chọn + mẫu mục
/// tiêu gợi ý theo phương pháp. Tạo gợi ý cần đã làm khảo sát trước (422 nếu chưa làm).
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Gợi ý cho bạn', style: GlassTypography.headlineMd()),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _RecommendationSection(),
              const SizedBox(height: 16),
              _CatalogSection(),
              const SizedBox(height: 16),
              _GoalSuggestionsSection(),
            ],
          ),
        ),
      ),
    );
  }
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
        messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      }
    }

    Future<void> skip(String id) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await controller.skip(id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      }
    }

    return GlassCard(
      level: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI FINANCIAL ADVISOR', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
          const SizedBox(height: 8),
          GlassPrimaryButton(
            key: const ValueKey('method-generate-recommendation'),
            label: 'Tạo gợi ý mới',
            onPressed: generate,
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
            data: (rec) {
              if (rec == null) {
                return Text('Chưa có gợi ý nào.', style: GlassTypography.bodyMd());
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                key: const ValueKey('method-recommendation-result'),
                children: [
                  Text(
                    'Nguồn: ${rec.source == 'ai' ? 'AI' : 'Quy tắc'} · Trạng thái: ${rec.outcome}',
                    style: GlassTypography.bodySm(),
                  ),
                  const SizedBox(height: 6),
                  Text('Chính: ${rec.primary.method.name}', style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                  Text(rec.primary.reason, style: GlassTypography.bodyMd()),
                  if (rec.support != null) ...[
                    const SizedBox(height: 10),
                    Text('Bổ trợ: ${rec.support!.method.name}', style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    Text(rec.support!.reason, style: GlassTypography.bodyMd()),
                  ],
                  if (rec.outcome == 'shown')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('method-skip-recommendation'),
                        onPressed: () => skip(rec.id),
                        child: Text('Bỏ qua gợi ý này', style: GlassTypography.bodyMd(color: GlassColors.textMuted)),
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danh mục cách quản lý', style: GlassTypography.headlineSm()),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                TextButton(onPressed: () => ref.invalidate(methodCatalogProvider), child: const Text('Thử lại')),
              ],
            ),
            data: (methods) => Column(
              children: [
                for (final m in methods)
                  Padding(
                    key: ValueKey('method-catalog-${m.code}'),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.name} (${_roleLabel(m.role)})',
                                style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(m.summary, style: GlassTypography.bodySm()),
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
        ],
      ),
    );
  }

  // Gọi thẳng repository thay vì qua `myMethodsControllerProvider.notifier`: provider đó là
  // autoDispose và không có nơi nào `watch` nó trong màn B4 này (chỉ B5 có `watch`), nên
  // `ref.read(...).notifier` có thể bị Riverpod huỷ giữa chừng khi request POST còn đang chạy,
  // ném ra lỗi state nội bộ (không phải ApiException/Exception) khiến UI chỉ hiện được thông
  // báo lỗi chung chung "Đã xảy ra lỗi. Vui lòng thử lại.".
  Future<void> _choose(BuildContext context, WidgetRef ref, String code, String role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(financeMethodsRepositoryProvider).chooseMethod(methodCode: code, role: role);
      ref.invalidate(myMethodsControllerProvider);
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã chọn cách quản lý.')));
      context.push('/finance-methods/my-methods');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }
}

class _GoalSuggestionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalSuggestionsProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mẫu mục tiêu gợi ý', style: GlassTypography.headlineSm()),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                TextButton(onPressed: () => ref.invalidate(goalSuggestionsProvider), child: const Text('Thử lại')),
              ],
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text('Chưa có mẫu mục tiêu phù hợp.', style: GlassTypography.bodyMd());
              }
              return Column(
                children: [
                  for (final g in list)
                    Padding(
                      key: ValueKey('goal-suggestion-${g.templateCode}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                          Text(g.description, style: GlassTypography.bodySm()),
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
}
