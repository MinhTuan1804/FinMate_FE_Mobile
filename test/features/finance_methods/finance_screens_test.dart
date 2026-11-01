import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/screens/recommendation_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/survey_screen.dart';
import 'fake_finance_repository.dart';

Future<void> pumpFlow(WidgetTester tester, FakeFinanceRepository repository, String initial) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/finance-survey', builder: (_, state) => SurveyScreen(onboarding: state.uri.queryParameters['onboarding'] == '1')),
      GoRoute(path: '/finance-recommendation', builder: (_, state) => RecommendationScreen(onboarding: state.uri.queryParameters['onboarding'] == '1')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [financeMethodsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('khảo sát', () {
    testWidgets('hiện câu đầu; chưa chọn đáp án thì chưa bấm Tiếp được', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpFlow(tester, repository, '/finance-survey?onboarding=1');

      expect(find.text(repository.survey.questions.first.text), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('survey_next'))).onPressed, isNull);

      await tester.tap(find.byKey(Key('option_${repository.survey.questions.first.options.first.code}')));
      await tester.pump();

      expect(tester.widget<ElevatedButton>(find.byKey(const Key('survey_next'))).onPressed, isNotNull);
    });

    testWidgets('trả lời hết thì chỉ gửi các câu ĐANG hiển thị rồi sang màn gợi ý', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpFlow(tester, repository, '/finance-survey?onboarding=1');

      // Mô phỏng người dùng luôn chọn đáp án đầu tiên; câu ẩn theo showIf không được gửi.
      final answers = <String, String>{};
      var step = 0;
      while (true) {
        final visible = visibleQuestions(repository.survey.questions, answers);
        if (step >= visible.length) break;
        final option = visible[step].options.first;
        answers[visible[step].code] = option.code;
        await tester.tap(find.byKey(Key('option_${option.code}')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('survey_next')));
        await tester.pumpAndSettle();
        step++;
        if (find.text('Gợi ý cho bạn').evaluate().isNotEmpty) break;
      }

      final expected = [for (final q in visibleQuestions(repository.survey.questions, answers)) '${q.code}=${answers[q.code]}'];
      expect(repository.submitted, hasLength(1));
      expect(repository.submitted.single.map((a) => '${a.questionCode}=${a.optionCode}'), expected);
      expect(find.text('Gợi ý cho bạn'), findsOneWidget);
    });

    testWidgets('để sau: hỏi lại, đồng ý thì báo backend và vào trang chủ', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpFlow(tester, repository, '/finance-survey?onboarding=1');

      await tester.tap(find.widgetWithText(TextButton, 'Để sau'));
      await tester.pumpAndSettle();
      expect(repository.skipSurveyCalls, 0, reason: 'chưa xác nhận thì chưa bỏ qua');

      await tester.tap(find.widgetWithText(FilledButton, 'Để sau'));
      await tester.pumpAndSettle();

      expect(repository.skipSurveyCalls, 1);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('backend từ chối khi nộp: hiện lỗi ngay trên màn và ở lại để sửa', (tester) async {
      final repository = FakeFinanceRepository(submitError: BusinessRuleException(code: 'X', message: 'Câu trả lời không hợp lệ.'));
      await pumpFlow(tester, repository, '/finance-survey?onboarding=1');

      final answers = <String, String>{};
      var step = 0;
      while (true) {
        final visible = visibleQuestions(repository.survey.questions, answers);
        if (step >= visible.length) break;
        final option = visible[step].options.first;
        answers[visible[step].code] = option.code;
        await tester.tap(find.byKey(Key('option_${option.code}')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('survey_next')));
        await tester.pumpAndSettle();
        step++;
      }

      expect(find.text('Câu trả lời không hợp lệ.'), findsOneWidget);
      expect(find.text('Gợi ý cho bạn'), findsNothing);
    });
  });

  group('gợi ý', () {
    testWidgets('hiện cách chính, lý do và nguồn gợi ý', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpFlow(tester, repository, '/finance-recommendation?onboarding=1');

      final primary = repository.recommendation.primary;
      expect(find.text(primary.method.name), findsOneWidget);
      expect(find.byKey(Key('reason_${primary.method.code}')), findsOneWidget);
      expect(find.text(repository.recommendation.fromAi ? 'AI gợi ý' : 'Gợi ý theo quy tắc'), findsOneWidget);
    });

    testWidgets('áp dụng cách chính: gửi đúng mã, vai trò và id gợi ý; xong thì vào trang chủ', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpFlow(tester, repository, '/finance-recommendation?onboarding=1');

      await tester.tap(find.byKey(const Key('apply_primary')));
      await tester.pumpAndSettle();

      expect(repository.chosen.single.code, repository.recommendation.primary.method.code);
      expect(repository.chosen.single.role, 'primary');
      expect(repository.chosen.single.recommendationId, repository.recommendation.id);
      expect(find.text('Đã áp dụng'), findsOneWidget);
      expect(find.byKey(const Key('skip_recommendation')), findsNothing, reason: 'đã áp dụng thì không còn bỏ qua gợi ý này');

      await tester.tap(find.byKey(const Key('done')));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('bỏ qua gợi ý: báo backend rồi vào trang chủ, không áp dụng gì', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpFlow(tester, repository, '/finance-recommendation?onboarding=1');

      await tester.tap(find.byKey(const Key('skip_recommendation')));
      await tester.pumpAndSettle();

      expect(repository.skippedRecommendations, [repository.recommendation.id]);
      expect(repository.chosen, isEmpty);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('chưa làm khảo sát: nói rõ và dẫn tới khảo sát', (tester) async {
      final repository = FakeFinanceRepository(
        recommendationError: BusinessRuleException(code: 'SURVEY_NOT_ANSWERED', message: 'Chưa có câu trả lời khảo sát nào.'),
      );
      await pumpFlow(tester, repository, '/finance-recommendation?onboarding=1');

      expect(find.text('Chưa có câu trả lời khảo sát nào.'), findsOneWidget);

      await tester.tap(find.text('Làm khảo sát'));
      await tester.pumpAndSettle();

      expect(find.text('Khảo sát nhanh'), findsOneWidget);
    });
  });
}
