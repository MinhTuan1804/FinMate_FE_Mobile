import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/survey/presentation/screens/survey_screen.dart';
import '../../fixtures/fixture.dart';

/// Khảo sát có phần số liệu (nhóm `money`): một câu chọn phương pháp, câu thu nhập (nhập số), câu tiền nhà (nhập số)
/// và câu chi ăn uống (chọn khoảng % thu nhập).
Map<String, dynamic> _survey({List<Map<String, dynamic>> answers = const []}) => {
      'success': true,
      'error': null,
      'meta': null,
      'data': {
        'status': 'pending',
        'completedAt': null,
        'answers': answers,
        'questions': [
          {
            'code': 'income_pattern',
            'group': 'cash_flow',
            'text': 'Thu nhập của bạn thường đến theo cách nào?',
            'showIf': null,
            'answerType': 'choice',
            'options': [
              {'code': 'A', 'text': 'Một khoản cố định'},
              {'code': 'B', 'text': 'Nhiều nguồn'},
            ],
          },
          {
            'code': 'income_amount',
            'group': 'money',
            'text': 'Mỗi tháng bạn thực nhận khoảng bao nhiêu?',
            'showIf': null,
            'answerType': 'amount',
            'planRole': 'income',
            'options': [],
          },
          {
            'code': 'fixed_housing',
            'group': 'money',
            'text': 'Tiền nhà hoặc tiền thuê trọ mỗi tháng',
            'showIf': null,
            'answerType': 'amount',
            'planRole': 'fixed',
            'categorySlug': 'housing',
            'options': [],
          },
          {
            'code': 'flex_food',
            'group': 'money',
            'text': 'Mỗi tháng bạn thường chi cho ăn uống khoảng bao nhiêu?',
            'showIf': null,
            'answerType': 'choice',
            'planRole': 'flexible',
            'categorySlug': 'food',
            'options': [
              {'code': 'C', 'text': 'Từ 5% đến 10%', 'shareMinPct': 5, 'shareMaxPct': 10},
              {'code': 'D', 'text': 'Từ 10% đến 20%', 'shareMinPct': 10, 'shareMaxPct': 20},
            ],
          },
        ],
      },
    };

Future<RouteAdapter> _pump(WidgetTester tester, {List<Map<String, dynamic>> answers = const []}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final adapter = RouteAdapter((o) {
    if (o.method == 'PUT') return respondJson(_survey(answers: answers));
    if (o.path.contains('/recommendations')) return respondJson({'success': true, 'data': null, 'error': null, 'meta': null});
    return respondJson(_survey(answers: answers));
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: SurveyScreen()),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

const _labels = {
  'Mỗi tháng bạn thực nhận khoảng bao nhiêu?': 'income_amount',
  'Tiền nhà hoặc tiền thuê trọ mỗi tháng': 'fixed_housing',
};

/// Ô nhập của một câu số tiền; nhãn hiện phía trên ô (GlassTextField) nên tìm ô theo key của câu, nhãn kiểm riêng.
Finder _amountField(String label) => find.descendant(
      of: find.byKey(ValueKey('survey-amount-${_labels[label]}')),
      matching: find.byType(TextFormField),
    );

void main() {
  group('SurveyScreen — phần số liệu', () {
    testWidgets('câu nhập số hiện ô nhập có nhãn, nằm chung một màn với các câu chọn', (tester) async {
      await _pump(tester);

      expect(find.text('Thu nhập của bạn thường đến theo cách nào?'), findsOneWidget);
      expect(find.text('Mỗi tháng bạn thực nhận khoảng bao nhiêu?'), findsOneWidget);
      expect(_amountField('Mỗi tháng bạn thực nhận khoảng bao nhiêu?'), findsOneWidget);
      expect(_amountField('Tiền nhà hoặc tiền thuê trọ mỗi tháng'), findsOneWidget);
      expect(find.text('Mỗi tháng bạn thường chi cho ăn uống khoảng bao nhiêu?'), findsOneWidget);
    });

    testWidgets('chưa nhập thu nhập thì khoảng chi hiện %, nhập rồi thì đổi ra số tiền', (tester) async {
      await _pump(tester);
      expect(find.text('10–20%'), findsOneWidget);

      await tester.enterText(_amountField('Mỗi tháng bạn thực nhận khoảng bao nhiêu?'), '10000000');
      await tester.pumpAndSettle();

      expect(find.text('10.000.000'), findsOneWidget, reason: 'tự thêm dấu chấm phần nghìn');
      expect(find.text('1–2tr'), findsOneWidget);
      expect(find.text('500k–1tr'), findsOneWidget);
    });

    testWidgets('ô số tiền bỏ chữ và dấu trừ', (tester) async {
      await _pump(tester);

      await tester.enterText(_amountField('Tiền nhà hoặc tiền thuê trọ mỗi tháng'), '-2a500000');
      await tester.pumpAndSettle();

      expect(find.text('2.500.000'), findsOneWidget);
    });

    testWidgets('gửi khảo sát mang số tiền ở amountVnd và đáp án ở optionCode', (tester) async {
      final adapter = await _pump(tester);

      await tester.tap(find.text('Một khoản cố định'));
      await tester.enterText(_amountField('Mỗi tháng bạn thực nhận khoảng bao nhiêu?'), '10000000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('1–2tr'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi khảo sát'));
      await tester.pumpAndSettle();

      final put = adapter.to('/survey/answers').single;
      final body = (put.data is String ? jsonDecode(put.data as String) : put.data) as Map<String, dynamic>;
      final answers = (body['answers'] as List).cast<Map<String, dynamic>>();
      expect(answers, containsAll([
        {'questionCode': 'income_pattern', 'optionCode': 'A'},
        {'questionCode': 'income_amount', 'amountVnd': 10000000},
        {'questionCode': 'flex_food', 'optionCode': 'D'},
      ]));
      expect(answers.any((a) => a['questionCode'] == 'fixed_housing'), isFalse, reason: 'ô trống không gửi');
    });

    testWidgets('câu trả lời số tiền đã lưu được điền lại vào ô', (tester) async {
      await _pump(tester, answers: [
        {'questionCode': 'income_amount', 'optionCode': null, 'amountVnd': 12000000},
      ]);

      expect(find.text('12.000.000'), findsOneWidget);
      expect(find.text('1,2–2,4tr'), findsOneWidget);
    });
  });
}
