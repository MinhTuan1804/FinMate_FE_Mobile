import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/survey/domain/survey.dart';
import 'package:finmate/features/survey/presentation/controllers/survey_controller.dart';

String _statusLabel(String status) => switch (status) {
      'pending' => 'Chưa làm',
      'completed' => 'Đã làm xong',
      'skipped' => 'Đã bỏ qua',
      _ => status,
    };

/// Màn test khảo sát đầu vào. Câu trả lời đang chọn trên máy (chưa gửi) là state cục bộ của màn
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
      _showMessage('Đã gửi khảo sát.');
    } catch (e) {
      _showMessage(surveyErrorMessage(e));
    }
  }

  Future<void> _skip() async {
    try {
      await ref.read(surveyControllerProvider.notifier).skip();
      _showMessage('Đã bỏ qua khảo sát.');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Khảo sát đầu vào')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(surveyErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: () => ref.read(surveyControllerProvider.notifier).load(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (survey) {
          if (survey == null) return const SizedBox.shrink();
          final visible = _visibleQuestions(survey);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Text('Trạng thái: '),
                      Text(_statusLabel(survey.status),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final q in visible)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                        for (final o in q.options)
                          RadioListTile<String>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(o.text),
                            value: o.code,
                            groupValue: _draftAnswers[q.code],
                            onChanged: (v) {
                              if (v != null) _choose(survey, q.code, v);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _draftAnswers.isEmpty ? null : () => _submit(survey),
                      child: const Text('Gửi khảo sát'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(onPressed: _skip, child: const Text('Bỏ qua')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _delete, child: const Text('Xóa khảo sát (reset)')),
            ],
          );
        },
      ),
    );
  }
}
