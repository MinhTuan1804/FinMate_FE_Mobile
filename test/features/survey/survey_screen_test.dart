import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/survey/presentation/screens/survey_screen.dart';
import '../../fixtures/fixture.dart';

RouteAdapter _adapterWith({String getFixture = 'survey_pending'}) {
  return RouteAdapter((o) {
    if (o.method == 'GET' && o.path.contains('/api/v1/survey')) {
      return respondFixture(getFixture);
    }
    if (o.method == 'PUT' && o.path.contains('/answers')) {
      return respondFixture('survey_completed');
    }
    if (o.method == 'POST' && o.path.contains('/skip')) {
      return respondFixture('survey_skipped');
    }
    if (o.method == 'DELETE') {
      return respondJson({'success': true, 'data': null, 'error': null, 'meta': null});
    }
    return respondFixture('survey_pending');
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: SurveyScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('SurveyScreen', () {
    testWidgets('tải xong thì hiện đủ 10 câu hỏi (saving_style ẩn vì chưa chọn main_goal)', (tester) async {
      await _pump(tester, _adapterWith());

      expect(find.text('Thu nhập của bạn thường đến theo cách nào?'), findsOneWidget);
      // saving_style có showIf phụ thuộc main_goal/month_end_balance, chưa trả lời main_goal → ẩn.
      expect(find.text('Bạn muốn dành tiền cho mục tiêu theo cách nào?'), findsNothing);
      expect(find.textContaining('Chưa làm'), findsOneWidget);
    });

    testWidgets('chọn main_goal=B và month_end_balance=A thì saving_style hiện ra ngay trên máy', (tester) async {
      await _pump(tester, _adapterWith());

      await tester.scrollUntilVisible(find.text('Còn dư đều đặn'), 300);
      await tester.tap(find.text('Còn dư đều đặn')); // month_end_balance = A
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn dành tiền cho mục tiêu theo cách nào?'), findsNothing);

      await tester.scrollUntilVisible(find.text('Tạo hoặc tăng quỹ dự phòng'), 300);
      await tester.tap(find.text('Tạo hoặc tăng quỹ dự phòng')); // main_goal = B
      await tester.pumpAndSettle();

      expect(find.text('Bạn muốn dành tiền cho mục tiêu theo cách nào?'), findsOneWidget);
    });

    testWidgets('đổi main_goal từ B sang A ẩn lại saving_style và xóa đáp án đã chọn cho nó', (tester) async {
      await _pump(tester, _adapterWith());

      await tester.scrollUntilVisible(find.text('Còn dư đều đặn'), 300);
      await tester.tap(find.text('Còn dư đều đặn'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tạo hoặc tăng quỹ dự phòng'), 300);
      await tester.tap(find.text('Tạo hoặc tăng quỹ dự phòng')); // main_goal = B
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn dành tiền cho mục tiêu theo cách nào?'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Chuyển tự động ngay khi nhận thu nhập'), 300);
      await tester.tap(find.text('Chuyển tự động ngay khi nhận thu nhập')); // saving_style = A
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Biết tiền đi đâu và tránh hụt cuối tháng'), 300);
      await tester.tap(find.text('Biết tiền đi đâu và tránh hụt cuối tháng')); // main_goal = A
      await tester.pumpAndSettle();

      expect(find.text('Bạn muốn dành tiền cho mục tiêu theo cách nào?'), findsNothing);
    });

    testWidgets('nút Gửi khảo sát bị khóa khi chưa chọn gì, mở khi đã chọn ít nhất một câu', (tester) async {
      await _pump(tester, _adapterWith());

      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Gửi khảo sát');
      ElevatedButton submitButton = tester.widget(submitButtonFinder);
      expect(submitButton.onPressed, isNull);

      await tester.tap(find.text('Còn dư đều đặn'));
      await tester.pumpAndSettle();

      submitButton = tester.widget(submitButtonFinder);
      expect(submitButton.onPressed, isNotNull);
    });

    testWidgets('gửi khảo sát chỉ kèm các câu đang hiện, cập nhật trạng thái sau khi gửi', (tester) async {
      final adapter = _adapterWith();
      await _pump(tester, adapter);

      await tester.tap(find.text('Một khoản cố định, đúng kỳ hằng tháng')); // income_pattern = A
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi khảo sát'));
      await tester.pumpAndSettle();

      final submitReq = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(submitReq.data, {
        'answers': [
          {'questionCode': 'income_pattern', 'optionCode': 'A'},
        ],
      });
      expect(find.textContaining('Đã gửi khảo sát'), findsOneWidget);
      expect(find.textContaining('Đã làm xong'), findsOneWidget);
    });

    testWidgets('bỏ qua khảo sát gọi đúng API và cập nhật trạng thái', (tester) async {
      final adapter = _adapterWith();
      await _pump(tester, adapter);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Bỏ qua'));
      await tester.pumpAndSettle();

      expect(adapter.requests.any((r) => r.method == 'POST' && r.path.contains('/skip')), isTrue);
      expect(find.textContaining('Đã bỏ qua khảo sát'), findsOneWidget);
      expect(find.textContaining('Đã bỏ qua'), findsWidgets);
    });

    testWidgets('xóa khảo sát: hủy ở hộp thoại thì không gọi API xóa', (tester) async {
      final adapter = _adapterWith();
      await _pump(tester, adapter);

      await tester.scrollUntilVisible(find.text('Xóa khảo sát (reset)'), 300);
      await tester.tap(find.text('Xóa khảo sát (reset)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(adapter.requests.any((r) => r.method == 'DELETE'), isFalse);
    });

    testWidgets('xóa khảo sát: xác nhận thì gọi DELETE rồi GET lại, về trạng thái chưa làm', (tester) async {
      final adapter = _adapterWith(getFixture: 'survey_completed');
      await _pump(tester, adapter);
      expect(find.textContaining('Đã làm xong'), findsOneWidget);

      // survey_completed có đủ 10 câu (saving_style cũng hiện vì đã có main_goal), dài hơn viewport test.
      await tester.scrollUntilVisible(find.text('Xóa khảo sát (reset)'), 300);
      await tester.tap(find.text('Xóa khảo sát (reset)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(adapter.requests.any((r) => r.method == 'DELETE'), isTrue);
      expect(find.textContaining('Đã xóa khảo sát'), findsOneWidget);
    });

    testWidgets('lỗi tải khảo sát hiện thông báo lỗi + nút thử lại', (tester) async {
      final adapter = RouteAdapter((o) => respondJson(
            {'success': false, 'data': null, 'error': {'code': 'SOME_ERROR', 'message': 'Lỗi mạng'}, 'meta': null},
            status: 500,
          ));
      await _pump(tester, adapter);

      expect(find.text('Lỗi mạng'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Thử lại'), findsOneWidget);
    });
  });
}
