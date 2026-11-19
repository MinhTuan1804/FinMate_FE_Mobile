import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/survey/domain/survey.dart';
import 'package:finmate/features/survey/presentation/controllers/survey_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_radio_card.dart';

/// Khảo sát đầu vào (B3). Câu trả lời đang chọn trên máy (chưa gửi) là state cục bộ của màn
/// hình ([_draftAnswers]) — mỗi khi đổi, lọc lại câu hiện/ẩn theo đúng logic ShowIf của BE ngay
/// trên máy, không cần gọi lại API.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  Map<String, String> _draftAnswers = {};
  bool _submitting = false;

  void _syncDraftFrom(SurveyEntity survey) {
    _draftAnswers = {for (final a in survey.answers) a.questionCode: a.optionCode};
  }

  List<SurveyQuestionEntity> _visibleQuestions(SurveyEntity survey) =>
      survey.questions.where((q) => q.isVisibleGiven(_draftAnswers)).toList();

  void _choose(SurveyEntity survey, String questionCode, String optionCode) {
    setState(() {
      _draftAnswers = {..._draftAnswers, questionCode: optionCode};
      final visibleCodes = _visibleQuestions(survey).map((q) => q.code).toSet();
      _draftAnswers = {
        for (final e in _draftAnswers.entries)
          if (visibleCodes.contains(e.key)) e.key: e.value,
      };
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit(SurveyEntity survey) async {
    final visibleCodes = _visibleQuestions(survey).map((q) => q.code).toSet();
    final answers = _draftAnswers.entries
        .where((e) => visibleCodes.contains(e.key))
        .map((e) => SurveyAnswerEntity(questionCode: e.key, optionCode: e.value))
        .toList();
    setState(() => _submitting = true);
    try {
      await ref.read(surveyControllerProvider.notifier).submit(answers);
      // Nộp lại khảo sát thì gợi ý cũ đã lỗi thời: tạo mới (backend tái dùng nếu tín hiệu không đổi). Lỗi AI/mạng không chặn luồng.
      try {
        await ref.read(financeMethodsRepositoryProvider).generateRecommendation();
      } catch (_) {}
      if (!mounted) return;
      _showMessage('Đã gửi khảo sát.');
      // Nối tiếp luồng: làm xong khảo sát thì đi thẳng sang màn gợi ý phương pháp (B4),
      // thay vì để người dùng tự tìm nút quay lại Hồ sơ.
      context.push('/finance-methods');
    } catch (e) {
      _showMessage(surveyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    try {
      await ref.read(surveyControllerProvider.notifier).skip();
      if (!mounted) return;
      _showMessage('Đã bỏ qua khảo sát.');
      // Nếu không còn màn nào bên dưới để quay lại (vào thẳng từ onboarding bằng context.go),
      // Navigator.canPop() == false — về Home thay vì để người dùng kẹt lại ở đây.
      if (!Navigator.of(context).canPop()) {
        context.go('/home');
      }
    } catch (e) {
      _showMessage(surveyErrorMessage(e));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khảo sát?'),
        content: const Text(
            'Câu trả lời và các gợi ý suy ra từ chúng sẽ bị xóa. Khảo sát về lại trạng thái chưa làm.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(surveyControllerProvider.notifier).deleteSurvey();
      _showMessage('Đã xóa khảo sát.');
    } catch (e) {
      _showMessage(surveyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SurveyEntity?>>(surveyControllerProvider, (previous, next) {
      next.whenData((survey) {
        if (survey != null) setState(() => _syncDraftFrom(survey));
      });
    });
    final state = ref.watch(surveyControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  tooltip: 'Quay lại',
                  icon: Icon(LucideIcons.arrowLeft, size: 20, color: GlassColors.textPrimary),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
          title: Text('Phương pháp quản lý', style: GlassTypography.headlineSm().copyWith(letterSpacing: -0.425)),
          actions: [
            // Giữ chức năng làm lại khảo sát (trước đây là nút chữ đỏ cuối trang), Figma không có chỗ riêng cho nó.
            if (state.valueOrNull != null)
              IconButton(
                tooltip: 'Xóa khảo sát (reset)',
                icon: Icon(LucideIcons.rotateCcw, size: 20, color: GlassColors.textSecondary),
                onPressed: _delete,
              ),
          ],
        ),
        body: SafeArea(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(surveyErrorMessage(e), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
                    const SizedBox(height: 16),
                    GlassSecondaryButton(
                      label: 'Thử lại',
                      onPressed: () => ref.read(surveyControllerProvider.notifier).load(),
                    ),
                  ],
                ),
              ),
            ),
            data: (survey) {
              if (survey == null) return const SizedBox.shrink();
              final visible = _visibleQuestions(survey);
              final answered = visible.where((q) => _draftAnswers.containsKey(q.code)).length;
              // Đã làm xong và chưa sửa câu nào: hành động chính là đi xem gợi ý (như Figma), sửa rồi mới gửi lại.
              final unchanged = survey.isCompleted &&
                  mapEquals(_draftAnswers, {for (final a in survey.answers) a.questionCode: a.optionCode});
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Semantics(
                      label: 'Đã trả lời $answered trên ${visible.length} câu',
                      child: GlassProgressBar(
                        percent: visible.isEmpty ? 0 : answered * 100 / visible.length,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        const _HeroIntro(),
                        const SizedBox(height: 16),
                        if (visible.isEmpty)
                          Text('Chưa có câu hỏi khảo sát.', style: GlassTypography.bodyMd()),
                        for (var i = 0; i < visible.length; i++) ...[
                          _QuestionSection(
                            number: i + 1,
                            question: visible[i],
                            selectedCode: _draftAnswers[visible[i].code],
                            onSelect: (optionCode) => _choose(survey, visible[i].code, optionCode),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                  if (_submitting)
                    Padding(
                      key: const ValueKey('survey-submitting-note'),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          'Đang phân tích câu trả lời và đưa ra gợi ý… có thể mất vài giây.',
                          textAlign: TextAlign.center,
                          style: GlassTypography.bodySm(color: GlassColors.textSecondary),
                        ),
                      ),
                    ),
                  GlassBottomDock(
                    actions: unchanged
                        ? [
                            GlassPrimaryButton(
                              key: const ValueKey('survey-go-to-recommendations'),
                              label: 'Xem gợi ý phương pháp của tôi',
                              icon: LucideIcons.trendingUp,
                              onPressed: () => context.push('/finance-methods'),
                            ),
                          ]
                        : [
                            GlassGhostButton(label: 'Bỏ qua', onPressed: _submitting ? null : _skip),
                            GlassPrimaryButton(
                              label: 'Gửi khảo sát',
                              loading: _submitting,
                              onPressed: _draftAnswers.isEmpty || _submitting ? null : () => _submit(survey),
                            ),
                          ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Thẻ mở đầu: nhãn + tiêu đề. Figma còn dòng "… ₫ của bạn" nhưng BE khảo sát không trả số liệu đó nên không dựng.
class _HeroIntro extends StatelessWidget {
  const _HeroIntro();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: GlassColors.fieldFill,
              borderRadius: GlassRadius.roundedPill,
              border: Border.all(color: GlassColors.fieldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 14, color: GlassColors.slateAnchor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'ĐỀ XUẤT CÁ NHÂN HOÁ',
                    style: GlassTypography.labelCaps(color: GlassColors.slateAnchor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text('Tìm phong cách tài chính phù hợp với bạn', style: GlassTypography.headlineMd().copyWith(letterSpacing: -0.5)),
          ),
        ],
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  final int number;
  final SurveyQuestionEntity question;
  final String? selectedCode;
  final ValueChanged<String> onSelect;

  const _QuestionSection({
    required this.number,
    required this.question,
    required this.selectedCode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 24),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: GlassColors.ink, borderRadius: GlassRadius.roundedPill),
              child: Text('$number', style: GlassTypography.labelCaps(color: GlassColors.onInk)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(question.text, style: GlassTypography.headlineSm()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < question.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          GlassRadioCard(
            title: question.options[i].text,
            selected: selectedCode == question.options[i].code,
            onTap: () => onSelect(question.options[i].code),
          ),
        ],
      ],
    );
  }
}
