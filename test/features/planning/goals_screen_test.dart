import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/screens/goals_screen.dart';
import 'goal_test_support.dart';

void main() {
  Future<MockGoalController> pump(WidgetTester tester, List<SavingsGoalEntity> goals) =>
      pumpGoalApp(tester, home: const GoalsScreen(), state: AsyncValue.data(planningWith(goals)));

  testWidgets('thẻ tổng cộng dồn các mục tiêu chưa hủy, không tràn ngang ở 360dp', (tester) async {
    await pump(tester, [
      testGoal(id: 'a', current: 28000000, target: 35000000),
      testGoal(id: 'b', current: 24000000, target: 45000000),
      testGoal(id: 'c', status: 'cancelled', current: 9000000, target: 10000000),
    ]);

    expect(find.text('52.000.000 ₫'), findsOneWidget);
    expect(find.text('Mục tiêu: 80.000.000 ₫'), findsOneWidget);
    expect(find.text('65%'), findsOneWidget);
    expect(find.text('Còn lại 28.000.000 ₫'), findsOneWidget);
    expect(find.text('2 mục tiêu đang chạy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chưa có mục tiêu: hiện thông báo trống và vẫn có nút tạo', (tester) async {
    await pump(tester, const []);
    expect(find.text('Bạn chưa có mục tiêu tiết kiệm nào.'), findsOneWidget);
    expect(find.text('Tạo mục tiêu mới'), findsOneWidget);
  });

  testWidgets('lỗi tải: hiện thông điệp thân thiện và nút Thử lại', (tester) async {
    await pumpGoalApp(
      tester,
      home: const GoalsScreen(),
      state: AsyncValue.error(Exception('Không có kết nối mạng'), StackTrace.empty),
    );
    expect(find.text('Không có kết nối mạng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('chip lọc chỉ hiện nhóm có dữ liệu và lọc đúng danh sách', (tester) async {
    await pump(tester, [
      testGoal(id: 'a', title: 'Quỹ A'),
      testGoal(id: 'b', title: 'Quỹ B', status: 'completed', current: 45000000),
    ]);

    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Đang chạy (1)'), findsOneWidget);
    expect(find.text('Hoàn thành (1)'), findsOneWidget);
    expect(find.textContaining('Đã hủy ('), findsNothing);
    expect(find.text('Ngắn hạn'), findsNothing);

    await tester.ensureVisible(find.text('Hoàn thành (1)'));
    await tester.tap(find.text('Hoàn thành (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Quỹ B'), findsOneWidget);
    expect(find.text('Quỹ A'), findsNothing);
  });

  testWidgets('chỉ một nhóm: ẩn hàng chip', (tester) async {
    await pump(tester, [testGoal()]);
    expect(find.textContaining('Tất cả ('), findsNothing);
  });

  testWidgets('nạp tiền mục tiêu: nhập số tiền, gọi controller và báo đã nạp', (tester) async {
    final mock = await pump(tester, [testGoal(deadline: DateTime(2027, 1, 1))]);
    mock.nextResult = testGoal(current: 2000000);

    await tester.tap(find.text('Nạp tiền vào mục tiêu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.000.000');
    await tester.tap(find.text('Nạp tiền'));
    await tester.pumpAndSettle();

    expect(mock.contributions.single.$1, 'g1');
    expect(mock.contributions.single.$2, BigInt.from(1000000));
    expect(find.text('Đã nạp 1.000.000 ₫ vào mục tiêu!'), findsOneWidget);
  });

  testWidgets('nạp tiền với số 0 bị chặn, không gọi controller', (tester) async {
    final mock = await pump(tester, [testGoal()]);

    await tester.tap(find.text('Nạp tiền vào mục tiêu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Nạp tiền'));
    await tester.pumpAndSettle();

    expect(mock.contributions, isEmpty);
    expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
  });

  testWidgets('hủy mục tiêu đang active: xác nhận rồi gọi controller.cancelGoal', (tester) async {
    final goal = testGoal();
    final mock = await pump(tester, [goal]);

    await tester.tap(find.byKey(ValueKey('cancel-goal-${goal.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hủy mục tiêu'));
    await tester.pumpAndSettle();

    expect(mock.cancelledGoalIds, [goal.id]);
    expect(find.text('Đã hủy mục tiêu'), findsOneWidget);
  });

  testWidgets('mục tiêu đã hoàn thành: không có nút hủy, nút nạp tiền bị khóa', (tester) async {
    final goal = testGoal(status: 'completed', current: 45000000);
    await pump(tester, [goal]);

    expect(find.byKey(ValueKey('cancel-goal-${goal.id}')), findsNothing);
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Nạp tiền vào mục tiêu'));
    expect(button.onPressed, isNull);
  });

  testWidgets('nút chi tiết mở màn G4', (tester) async {
    final goal = testGoal();
    await pumpGoalApp(
      tester,
      home: const GoalsScreen(),
      state: AsyncValue.data(planningWith([goal])),
      prepare: (m) => m.nextProgress = null,
    );

    await tester.tap(find.byKey(ValueKey('goal-screen-${goal.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('contribute-goal')), findsOneWidget);
  });

  testWidgets('Tạo mục tiêu mới mở form tạo; sửa mở form sửa', (tester) async {
    final goal = testGoal();
    await pump(tester, [goal]);

    await tester.tap(find.byKey(const ValueKey('create-goal')));
    await tester.pumpAndSettle();
    expect(find.text('Lưu mục tiêu'), findsOneWidget);
    expect(find.text('Tạo mục tiêu mới'), findsOneWidget);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('edit-goal-${goal.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa mục tiêu'), findsOneWidget);
  });
}
