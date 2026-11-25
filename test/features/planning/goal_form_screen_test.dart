import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/screens/goal_form_screen.dart';
import 'goal_test_support.dart';

void main() {
  Future<MockGoalController> pump(WidgetTester tester, {SavingsGoalEntity? goal, void Function(MockGoalController)? prepare}) =>
      pumpGoalApp(
        tester,
        home: GoalFormScreen(goal: goal),
        state: AsyncValue.data(planningWith(const [])),
        prepare: prepare,
      );

  testWidgets('sửa mục tiêu: điền sẵn dữ liệu (tiền có dấu chấm), đổi tên gọi updateGoal', (tester) async {
    final goal = testGoal(deadline: DateTime(2027, 1, 1));
    final mock = await pump(tester, goal: goal);

    expect(find.text('Sửa mục tiêu'), findsOneWidget);
    expect(find.text('45.000.000'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Quỹ khẩn cấp (mới)');
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();

    expect(mock.goalUpdates.single.id, goal.id);
    expect(mock.goalUpdates.single.name, 'Quỹ khẩn cấp (mới)');
    expect(mock.goalUpdates.single.target, BigInt.from(45000000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tạo mới: nhập tên + số tiền thì gọi createSavingsGoal', (tester) async {
    final mock = await pump(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Du lịch');
    await tester.enterText(find.byType(TextFormField).at(1), '35000000');
    await tester.pump();
    expect(find.text('35.000.000'), findsOneWidget);
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();

    expect(mock.goalCreates.single.title, 'Du lịch');
    expect(mock.goalCreates.single.target, BigInt.from(35000000));
    expect(mock.goalCreates.single.deadline, isNull);
  });

  testWidgets('thiếu tên hoặc số tiền không hợp lệ: báo lỗi, không gọi controller', (tester) async {
    final mock = await pump(tester);

    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên mục tiêu'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Du lịch');
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
    expect(mock.goalCreates, isEmpty);
  });

  testWidgets('chưa xem trước thì không hiện số liệu khả thi', (tester) async {
    await pump(tester, goal: testGoal(deadline: DateTime(2027, 1, 1)));
    expect(find.text('Khả thi AI'), findsOneWidget);
    expect(find.textContaining('Cần ~'), findsNothing);
  });

  testWidgets('xem trước khả thi (đã có hạn chót) gọi previewFeasibility và hiện kết quả', (tester) async {
    final mock = await pump(
      tester,
      goal: testGoal(deadline: DateTime(2027, 1, 1)),
      prepare: (m) => m.nextFeasibility = GoalFeasibilityEntity(requiredPerMonthCents: BigInt.from(5000000), isFeasible: true),
    );

    await tester.tap(find.text('Xem trước tính khả thi'));
    await tester.pumpAndSettle();

    expect(mock.previewFeasibilityCalls, 1);
    expect(find.textContaining('Cần ~5.000.000'), findsOneWidget);
  });

  testWidgets('không khả thi: cảnh báo vượt khả năng tài chính', (tester) async {
    await pump(
      tester,
      goal: testGoal(deadline: DateTime(2027, 1, 1)),
      prepare: (m) => m.nextFeasibility = GoalFeasibilityEntity(requiredPerMonthCents: BigInt.from(22000000), isFeasible: false),
    );

    await tester.tap(find.text('Xem trước tính khả thi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('vượt khả năng tài chính hiện tại'), findsOneWidget);
  });

  testWidgets('xem trước khả thi: thiếu hạn chót thì báo lỗi, không gọi controller', (tester) async {
    final mock = await pump(tester, goal: testGoal(deadline: null));

    await tester.tap(find.text('Xem trước tính khả thi'));
    await tester.pumpAndSettle();

    expect(mock.previewFeasibilityCalls, 0);
    expect(find.text('Vui lòng chọn hạn chót để xem khả thi'), findsOneWidget);
  });
}
