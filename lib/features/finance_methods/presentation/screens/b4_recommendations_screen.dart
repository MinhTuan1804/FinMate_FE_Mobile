import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
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

// outcome của BE: 'shown'|'accepted'|'changed'|'skipped'
String _outcomeLabel(String outcome) => switch (outcome) {
      'shown' => 'Chờ bạn quyết định',
      'accepted' => 'Đã áp dụng',
      'changed' => 'Đã đổi sang cách khác',
      'skipped' => 'Đã bỏ qua',
      _ => 'Đã xử lý',
    };

/// Các tham số phần trăm mô tả cách chia (loại ngưỡng cảnh báo t1/t2, vốn không phải tỷ lệ phân bổ).
List<ParamEntity> _allocationParams(MethodEntity m) =>
    m.params.where((p) => p.type == 'percent' && p.key != 't1_pct' && p.key != 't2_pct').toList();

/// B4 — Gợi ý phương pháp quản lý tài chính: gợi ý AI/quy tắc + danh mục để tự chọn + mẫu mục
/// tiêu gợi ý theo phương pháp. Tạo gợi ý cần đã làm khảo sát trước (422 nếu chưa làm).
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(context, title: 'Gợi ý cho bạn'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _RecommendationSection(),
              const SizedBox(height: 24),
              _CatalogSection(),
              const SizedBox(height: 24),
              _GoalSuggestionsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: GlassTypography.headlineSm())),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!.toUpperCase(), style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Dòng lỗi + nút thử lại dùng chung cho các khối tải dữ liệu.
class _ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(errorMessage(error), style: GlassTypography.bodySm(color: GlassColors.danger)),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
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

    // "Áp dụng gợi ý" = chọn đúng cách AI gợi ý: cách chính TRƯỚC (backend ghi gợi ý là "accepted" khi cách chính trùng), rồi cách bổ trợ nếu có.
    // Gọi thẳng repository vì cùng lý do ở _CatalogSection._choose. Bổ trợ lỗi thì cách chính vẫn đã áp dụng: tải lại để màn hiện đúng trạng thái.
    Future<void> apply(RecommendationEntity rec) async {
      final messenger = ScaffoldMessenger.of(context);
      final repository = ref.read(financeMethodsRepositoryProvider);
      try {
        await repository.chooseMethod(methodCode: rec.primary.method.code, role: 'primary', recommendationId: rec.id);
        final support = rec.support;
        if (support != null) {
          await repository.chooseMethod(methodCode: support.method.code, role: 'supporting', recommendationId: rec.id);
        }
        ref.invalidate(myMethodsControllerProvider);
        await controller.loadLatest();
        if (!context.mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Đã áp dụng gợi ý.')));
        context.push('/finance-methods/my-methods');
      } catch (e) {
        ref.invalidate(myMethodsControllerProvider);
        await controller.loadLatest();
        messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...async.maybeWhen(
          data: (rec) => rec == null ? <Widget>[] : <Widget>[_AdvisorBadge(isAi: rec.source == 'ai'), const SizedBox(height: 16)],
          orElse: () => <Widget>[],
        ),
        GlassCard(
          level: 2,
          borderRadius: GlassRadius.roundedHero,
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              async.when(
                loading: () => Padding(
                  key: const ValueKey('method-recommendation-loading'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Đang phân tích khảo sát và đưa ra gợi ý… có thể mất vài giây.',
                          style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                data: (rec) {
                  if (rec == null) {
                    return Text('Chưa có gợi ý nào.', style: GlassTypography.bodyMd());
                  }
                  final allocation = _allocationParams(rec.primary.method);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    key: const ValueKey('method-recommendation-result'),
                    children: [
                      Text(
                        'Nguồn: ${rec.source == 'ai' ? 'AI' : 'Quy tắc'} · ${_outcomeLabel(rec.outcome)}',
                        style: GlassTypography.labelCaps(color: GlassColors.slateAnchor),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        // Tên phương pháp một dòng, tự thu nhỏ chữ khi dài thay vì xuống hàng.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            rec.primary.method.name,
                            maxLines: 1,
                            style: GlassTypography.headlineMd().copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(rec.primary.reason, style: GlassTypography.bodyMd().copyWith(height: 22.75 / 14)),
                      if (allocation.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text('TỶ LỆ PHÂN BỔ', style: GlassTypography.labelCaps()),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < allocation.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _AllocationRow(index: i + 1, param: allocation[i]),
                        ],
                      ],
                      if (rec.support != null) ...[
                        const SizedBox(height: 20),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Bổ trợ: ${rec.support!.method.name}', maxLines: 1, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 4),
                        Text(rec.support!.reason, style: GlassTypography.bodyMd()),
                      ],
                      if (rec.outcome == 'shown') ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: GlassPrimaryButton(
                            key: const ValueKey('method-apply-recommendation'),
                            label: 'Áp dụng phương pháp này',
                            icon: LucideIcons.arrowRight,
                            onPressed: () => apply(rec),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const ValueKey('method-skip-recommendation'),
                            onPressed: () => skip(rec.id),
                            child: Text('Bỏ qua gợi ý này', style: GlassTypography.bodyMd(color: GlassColors.textMuted)),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GlassGhostButton(
                  key: const ValueKey('method-generate-recommendation'),
                  label: 'Tạo gợi ý mới',
                  onPressed: async.isLoading ? null : generate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ nhỏ đầu màn: gợi ý đến từ AI hay từ quy tắc. Không có số liệu thu nhập vì BE gợi ý không trả về.
class _AdvisorBadge extends StatelessWidget {
  final bool isAi;

  const _AdvisorBadge({required this.isAi});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), shape: BoxShape.circle),
            child: Icon(LucideIcons.sparkles, size: 18, color: GlassColors.slateAnchor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isAi ? 'AI FINANCIAL ADVISOR' : 'GỢI Ý THEO QUY TẮC',
                        style: GlassTypography.labelCaps(color: GlassColors.slateAnchor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: GlassColors.success, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Khuyến nghị dựa trên hồ sơ của bạn', style: GlassTypography.bodySm()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  final int index;
  final ParamEntity param;

  const _AllocationRow({required this.index, required this.param});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), shape: BoxShape.circle),
                child: Text('$index', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor).copyWith(fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  param.label,
                  style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${param.defaultValue}%', style: GlassTypography.labelNumeric().copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: '${param.label}: ${param.defaultValue}%',
            excludeSemantics: true,
            child: GlassProgressBar(percent: param.defaultValue.toDouble(), height: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Phương án khác tham khảo',
          trailing: async.maybeWhen(data: (m) => '${m.length} lựa chọn', orElse: () => null),
        ),
        async.when(
          loading: () => const GlassLoadingSpinner(),
          error: (e, __) => _ErrorRetry(error: e, onRetry: () => ref.invalidate(methodCatalogProvider)),
          data: (methods) => Column(
            children: [
              for (final m in methods)
                Padding(
                  key: ValueKey('method-catalog-${m.code}'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_roleLabel(m.role), style: GlassTypography.bodySm()),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(m.name, maxLines: 1, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        Text(m.summary, style: GlassTypography.bodySm(color: GlassColors.textSecondary).copyWith(height: 16.5 / 12)),
                        if (m.canBePrimary || m.canBeSupport) ...[
                          const SizedBox(height: 14),
                          // Nút thật (nền + viền rõ), cùng hàng chia đều; nhãn tự thu nhỏ nếu hẹp.
                          Row(
                            children: [
                              if (m.canBePrimary)
                                Expanded(
                                  child: GlassPrimaryButton(
                                    key: ValueKey('method-choose-primary-${m.code}'),
                                    label: 'Chọn chính',
                                    onPressed: () => _choose(context, ref, m.code, 'primary'),
                                  ),
                                ),
                              if (m.canBePrimary && m.canBeSupport) const SizedBox(width: 10),
                              if (m.canBeSupport)
                                Expanded(
                                  child: GlassSecondaryButton(
                                    key: ValueKey('method-choose-supporting-${m.code}'),
                                    label: 'Chọn bổ trợ',
                                    onPressed: () => _choose(context, ref, m.code, 'supporting'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Mẫu mục tiêu gợi ý'),
        async.when(
          loading: () => const GlassLoadingSpinner(),
          error: (e, __) => _ErrorRetry(error: e, onRetry: () => ref.invalidate(goalSuggestionsProvider)),
          data: (list) {
            if (list.isEmpty) {
              return Text('Chưa có mẫu mục tiêu phù hợp.', style: GlassTypography.bodyMd());
            }
            return Column(
              children: [
                for (final g in list)
                  Padding(
                    key: ValueKey('goal-suggestion-${g.templateCode}'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(g.description, style: GlassTypography.bodySm(color: GlassColors.textSecondary).copyWith(height: 16.5 / 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
