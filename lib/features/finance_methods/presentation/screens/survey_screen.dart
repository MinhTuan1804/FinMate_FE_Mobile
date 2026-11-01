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

/// Màn KHẢO SÁT: từng câu một, câu có điều kiện (`showIf`) tự ẩn/hiện theo câu trả lời trước, bỏ qua được.
/// [onboarding] = mở ngay sau thiết lập ban đầu (đi tiếp bằng `go`, không có màn trước để quay lại); không thì mở từ trang chủ (đi tiếp bằng `push`).
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  final Map<String, String> _answers = {};
  bool _seeded = false;
  int _index = 0;
  bool _busy = false;
  String? _error;

  List<SurveyQuestion> _visible(Survey survey) => visibleQuestions(survey.questions, _answers);

  /// Làm lại khảo sát thì điền sẵn câu trả lời cũ.
  void _seed(Survey survey) {
    if (_seeded) return;
    _seeded = true;
    _answers.addEntries(survey.answers.map((a) => MapEntry(a.questionCode, a.optionCode)));
  }

  void _select(Survey survey, SurveyQuestion question, SurveyOption option) {
    setState(() {
      _answers[question.code] = option.code;
      // Đổi một câu trả lời có thể làm câu sau ẩn đi; đừng để chỉ số đứng ngoài danh sách câu đang hiển thị.
      final count = _visible(survey).length;
      if (_index >= count) _index = count - 1;
      _error = null;
    });
  }

  Future<void> _submit(Survey survey) async {
    final answers = [
      for (final question in _visible(survey))
        if (_answers[question.code] case final option?) SurveyAnswer(question.code, option),
    ];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(financeMethodsRepositoryProvider).submitSurvey(answers);
      ref.invalidate(surveyProvider);
      if (!mounted) return;
      if (widget.onboarding) {
        context.go('/finance-recommendation?onboarding=1');
      } else {
        context.pushReplacement('/finance-recommendation');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = errorMessage(error);
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmSkip() async {
    final skip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Để sau?'),
        content: const Text('Bạn vẫn dùng app bình thường và có thể tự chọn cách quản lý tài chính. Làm khảo sát lúc nào cũng được.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Làm tiếp')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Để sau')),
        ],
      ),
    );
    if (skip != true) return;
    try {
      await ref.read(financeMethodsRepositoryProvider).skipSurvey();
      ref.invalidate(surveyProvider);
      if (!mounted) return;
      if (widget.onboarding) {
        context.go('/home');
      } else {
        context.pop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final survey = ref.watch(surveyProvider);
    return PopScope(
      // Ở chế độ thiết lập ban đầu không có màn trước: Quay lại = về câu trước, hết câu thì hỏi để sau; không thoát app.
      canPop: !widget.onboarding,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          setState(() => _index--);
        } else {
          _confirmSkip();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Khảo sát nhanh', style: AppTypography.h3(context)),
          actions: [
            if (survey.hasValue) TextButton(onPressed: _busy ? null : _confirmSkip, child: const Text('Để sau')),
          ],
        ),
        body: SafeArea(
          child: survey.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => FinanceFailure(message: errorMessage(error), onRetry: () => ref.invalidate(surveyProvider)),
            data: _content,
          ),
        ),
      ),
    );
  }

  Widget _content(Survey survey) {
    _seed(survey);
    final visible = _visible(survey);
    if (visible.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Text('Hiện chưa có câu hỏi nào.')));
    }
    final question = visible[_index];
    final selected = _answers[question.code];
    final isLast = _index == visible.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: LinearProgressIndicator(
            value: (_index + 1) / visible.length,
            semanticsLabel: 'Tiến độ khảo sát, câu ${_index + 1} trên ${visible.length}',
            minHeight: 6,
            borderRadius: AppSpacing.roundedPill,
            color: AppColors.primary,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Câu ${_index + 1}/${visible.length}', style: AppTypography.caption(context)),
              const SizedBox(height: AppSpacing.sm),
              Text(question.text, key: const Key('survey_question'), style: AppTypography.h2(context)),
              if (_index == 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'FinMate dùng câu trả lời để gợi ý cách quản lý tài chính hợp với bạn. Chỉ các dấu hiệu ẩn danh được chuyển cho AI, và bạn không bị buộc áp dụng gợi ý.',
                  style: AppTypography.caption(context),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              for (final option in question.options)
                _OptionTile(
                  key: Key('option_${option.code}'),
                  text: option.text,
                  selected: selected == option.code,
                  enabled: !_busy,
                  onTap: () => _select(survey, question, option),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_error!, style: AppTypography.caption(context).copyWith(color: AppColors.danger))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Row(
            children: [
              if (_index > 0)
                TextButton(
                  key: const Key('survey_back'),
                  onPressed: _busy ? null : () => setState(() => _index--),
                  child: const Text('Quay lại'),
                ),
              const Spacer(),
              ElevatedButton(
                key: const Key('survey_next'),
                onPressed: selected == null || _busy
                    ? null
                    : isLast
                        ? () => _submit(survey)
                        : () => setState(() => _index++),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 48),
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                ),
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isLast ? 'Hoàn tất' : 'Tiếp', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Một đáp án: vùng chạm cao ≥ 56, trạng thái chọn thể hiện bằng icon + viền (không chỉ bằng màu).
class _OptionTile extends StatelessWidget {
  const _OptionTile({super.key, required this.text, required this.selected, required this.enabled, required this.onTap});

  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: text,
        child: ExcludeSemantics(
          child: Material(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            shape: RoundedRectangleBorder(
              borderRadius: AppSpacing.roundedMedium,
              side: BorderSide(
                color: selected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: AppSpacing.roundedMedium,
              onTap: enabled ? onTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        selected ? LucideIcons.circleCheck : LucideIcons.circle,
                        size: 20,
                        color: selected ? AppColors.primary : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(text, style: AppTypography.body(context))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
