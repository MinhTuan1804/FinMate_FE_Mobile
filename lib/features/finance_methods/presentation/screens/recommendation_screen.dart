import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_providers.dart';
import 'package:finmate/features/finance_methods/presentation/widgets/finance_widgets.dart';

/// Màn GỢI Ý cách quản lý tài chính: tạo gợi ý từ câu trả lời khảo sát (AI chọn, luật là dự phòng), hiện cách chính và cách bổ trợ kèm lý do,
/// cho người dùng ÁP DỤNG, tự chọn cách khác trong danh mục, hoặc bỏ qua. Gợi ý chỉ để tham khảo: dùng hay không là quyền của người dùng.
/// [onboarding] = đi tiếp từ khảo sát lúc thiết lập ban đầu; xong thì vào trang chủ bằng `go`.
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  ConsumerState<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  Recommendation? _recommendation;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _errorCode;
  final Set<String> _applied = {}; // mã các cách đã áp dụng trong lần xem này

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorCode = null;
    });
    try {
      final recommendation = await ref.read(financeMethodsRepositoryProvider).generateRecommendation();
      if (!mounted) return;
      setState(() {
        _recommendation = recommendation;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error);
        _errorCode = error is ApiException ? error.code : null;
        _loading = false;
      });
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _apply(FinanceMethod method, String role) async {
    final recommendation = _recommendation;
    if (recommendation == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(financeMethodsRepositoryProvider).chooseMethod(methodCode: method.code, role: role, recommendationId: recommendation.id);
      refreshFinanceMethods(ref);
      if (!mounted) return;
      setState(() {
        _applied.add(method.code);
        _busy = false;
      });
      _showMessage('Đã áp dụng "${method.name}" làm ${roleLabel(role).toLowerCase()}.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(errorMessage(error));
    }
  }

  Future<void> _skip() async {
    final recommendation = _recommendation;
    if (recommendation == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(financeMethodsRepositoryProvider).skipRecommendation(recommendation.id);
      if (mounted) _finish();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(errorMessage(error));
    }
  }

  void _finish() {
    if (widget.onboarding) {
      context.go('/home');
    } else {
      context.pop();
    }
  }

  Future<void> _pickOther() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CatalogSheet(
        applied: _applied,
        onApply: (method, role) async {
          Navigator.of(sheetContext).pop();
          await _apply(method, role);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.onboarding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Gợi ý cho bạn', style: AppTypography.h3(context))),
        body: SafeArea(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text('Đang phân tích câu trả lời của bạn...', style: AppTypography.body(context)),
          ],
        ),
      );
    }
    final recommendation = _recommendation;
    if (recommendation == null) {
      final needsSurvey = _errorCode == 'SURVEY_NOT_ANSWERED';
      return FinanceFailure(
        message: _error ?? 'Không tạo được gợi ý.',
        onRetry: _load,
        secondary: needsSurvey
            ? TextButton(
                onPressed: () => widget.onboarding ? context.go('/finance-survey?onboarding=1') : context.pushReplacement('/finance-survey'),
                child: const Text('Làm khảo sát'),
              )
            : TextButton(onPressed: _pickOther, child: const Text('Tự chọn cách quản lý')),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          key: const Key('source_chip'),
          children: [
            Icon(recommendation.fromAi ? LucideIcons.sparkles : LucideIcons.listChecks, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              recommendation.fromAi ? 'AI gợi ý' : 'Gợi ý theo quy tắc',
              style: AppTypography.bodyMedium(context).copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Đây chỉ là gợi ý để bạn tham khảo. Dùng hay không là quyền của bạn.', style: AppTypography.caption(context)),
        const SizedBox(height: AppSpacing.lg),
        _RecommendedCard(
          title: 'Cách chính',
          item: recommendation.primary,
          fromAi: recommendation.fromAi,
          applied: _applied.contains(recommendation.primary.method.code),
          busy: _busy,
          actionKey: const Key('apply_primary'),
          actionLabel: 'Dùng làm cách chính',
          onApply: () => _apply(recommendation.primary.method, 'primary'),
        ),
        if (recommendation.support case final support?) ...[
          const SizedBox(height: AppSpacing.md),
          _RecommendedCard(
            title: 'Cách bổ trợ',
            item: support,
            fromAi: recommendation.fromAi,
            applied: _applied.contains(support.method.code),
            busy: _busy,
            actionKey: const Key('apply_support'),
            actionLabel: 'Thêm làm cách bổ trợ',
            onApply: () => _apply(support.method, 'supporting'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (_applied.isNotEmpty)
          ElevatedButton(
            key: const Key('done'),
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
            ),
            child: Text(widget.onboarding ? 'Vào trang chủ' : 'Xong', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            TextButton(key: const Key('pick_other'), onPressed: _busy ? null : _pickOther, child: const Text('Chọn cách khác')),
            if (_applied.isEmpty)
              TextButton(key: const Key('skip_recommendation'), onPressed: _busy ? null : _skip, child: const Text('Để sau, bỏ qua gợi ý')),
          ],
        ),
      ],
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.title,
    required this.item,
    required this.fromAi,
    required this.applied,
    required this.busy,
    required this.actionKey,
    required this.actionLabel,
    required this.onApply,
  });

  final String title;
  final RecommendedMethod item;
  final bool fromAi;
  final bool applied;
  final bool busy;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinanceSectionLabel(title),
          const SizedBox(height: AppSpacing.xs),
          Text(item.method.name, style: AppTypography.h3(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(item.method.summary, style: AppTypography.caption(context)),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: AppSpacing.roundedSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(fromAi ? LucideIcons.sparkles : LucideIcons.listChecks, size: 14, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Vì sao hợp với bạn', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(item.reason, key: Key('reason_${item.method.code}'), style: AppTypography.body(context)),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text('Xem chi tiết', style: AppTypography.bodyMedium(context)),
              children: [MethodDetails(method: item.method, showWhy: false)],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: applied
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(LucideIcons.circleCheck, size: 18),
                    label: const Text('Đã áp dụng'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  )
                : ElevatedButton(
                    key: actionKey,
                    onPressed: busy ? null : onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                    ),
                    child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Danh mục mọi cách đang bật: người dùng tự chọn khi không theo gợi ý. Cách nào chỉ làm được vai trò nào thì chỉ hiện nút vai trò đó.
class _CatalogSheet extends ConsumerWidget {
  const _CatalogSheet({required this.applied, required this.onApply});

  final Set<String> applied;
  final Future<void> Function(FinanceMethod method, String role) onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(financeCatalogProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => FinanceFailure(message: errorMessage(error), onRetry: () => ref.invalidate(financeCatalogProvider)),
        data: (methods) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Chọn cách bạn muốn dùng', style: AppTypography.h3(context)),
            const SizedBox(height: AppSpacing.md),
            for (final method in methods)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: FinanceCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: Key('catalog_${method.code}'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      title: Text(method.name, style: AppTypography.bodyLarge(context)),
                      subtitle: Text(
                        '${roleLabel(method.role)} · ${method.summary}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(context),
                      ),
                      children: [
                        MethodDetails(method: method),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            if (method.canBePrimary)
                              ElevatedButton(
                                key: Key('catalog_primary_${method.code}'),
                                onPressed: applied.contains(method.code) ? null : () => onApply(method, 'primary'),
                                child: const Text('Dùng làm cách chính'),
                              ),
                            if (method.canBeSupporting)
                              OutlinedButton(
                                key: Key('catalog_support_${method.code}'),
                                onPressed: applied.contains(method.code) ? null : () => onApply(method, 'supporting'),
                                child: const Text('Dùng làm cách bổ trợ'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
