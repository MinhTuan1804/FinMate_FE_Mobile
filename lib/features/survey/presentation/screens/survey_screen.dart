import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/survey/domain/survey.dart';
import 'package:finmate/features/survey/presentation/controllers/survey_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_radio_card.dart';

String _statusLabel(String status) => switch (status) {
      'pending' => 'Chưa làm',
      'completed' => 'Đã làm xong',
      'skipped' => 'Đã bỏ qua',
      _ => status,
    };

/// Khảo sát đầu vào. Câu trả lời đang chọn trên máy (chưa gửi) là state cục bộ của màn
/// hình ([_draftAnswers]) — mỗi khi đổi, lọc lại câu hiện/ẩn theo đúng logic ShowIf của BE ngay
/// trên máy, không cần gọi lại API.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  Map<String, String> _draftAnswers = {};

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
    try {
      await ref.read(surveyControllerProvider.notifier).submit(answers);
      if (!mounted) return;
      _showMessage('Đã gửi khảo sát.');
      // Nối tiếp luồng: làm xong khảo sát thì đi thẳng sang màn gợi ý phương pháp (B4),
      // thay vì để người dùng tự tìm nút quay lại Hồ sơ.
      context.push('/finance-methods');
    } catch (e) {
      _showMessage(surveyErrorMessage(e));
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
          title: Text('Khảo sát đầu vào', style: GlassTypography.headlineMd()),
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
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Trạng thái: ', style: GlassTypography.bodyMd()),
                                  Text(
                                    _statusLabel(survey.status),
                                    style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              if (survey.status == 'completed') ...[
                                const SizedBox(height: 10),
                                GlassSecondaryButton(
                                  key: const ValueKey('survey-go-to-recommendations'),
                                  label: 'Xem gợi ý phương pháp',
                                  onPressed: () => context.push('/finance-methods'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final q in visible) ...[
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.text,
                                  style: GlassTypography.headlineSm(),
                                ),
                                const SizedBox(height: 12),
                                for (final o in q.options) ...[
                                  GlassRadioCard(
                                    title: o.text,
                                    selected: _draftAnswers[q.code] == o.code,
                                    onTap: () => _choose(survey, q.code, o.code),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextButton(
                          onPressed: _delete,
                          child: Text('Xóa khảo sát (reset)', style: GlassTypography.bodyMd(color: GlassColors.danger)),
                        ),
                      ],
                    ),
                  ),
                  GlassBottomDock(
                    actions: [
                      GlassGhostButton(label: 'Bỏ qua', onPressed: _skip),
                      GlassPrimaryButton(
                        label: 'Gửi khảo sát',
                        onPressed: _draftAnswers.isEmpty ? null : () => _submit(survey),
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
