import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/screens/savings_goal_detail_screen.dart';
import 'goal_test_support.dart';

GoalProgressEntity _progress({List<GoalContributionEntity> contributions = const []}) => GoalProgressEntity(
  goalId: 'g1',
  name: 'Quỹ khẩn cấp',
  status: 'active',
  targetCents: BigInt.from(45000000),
  savedCents: BigInt.from(1000000),
  remainingCents: BigInt.from(44000000),
  percentComplete: 2,
  daysRemaining: 55,
  requiredPerDayCents: BigInt.from(800000),
  isOnTrack: false,
  recentContributions: contributions,
);

void main() {
  Future<MockGoalController> pump(WidgetTester tester, SavingsGoalEntity goal, {GoalProgressEntity? progress}) => pumpGoalApp(
    tester,
    home: SavingsGoalDetailScreen(goal: goal),
    state: AsyncValue.data(planningWith([goal])),
    prepare: (m) => m.nextProgress = progress,
  );

  testWidgets('hiện % đã đạt, hiện có/mục tiêu, số ngày còn lại, lịch sử đóng góp; không tràn ở 360dp', (tester) async {
    await pump(
      tester,
      testGoal(deadline: DateTime(2027, 1, 1)),
      progress: _progress(
        contributions: [
          GoalContributionEntity(id: 'c1', amountCents: BigInt.from(2000000), note: 'Lương', contributedAt: DateTime(2026, 10, 28)),
        ],
      ),
    );

    expect(find.text('ĐÃ ĐẠT'), findsOneWidget);
    expect(find.text('2%'), findsOneWidget);
    expect(find.text('Còn 55 ngày'), findsOneWidget);
    expect(find.text('1.000.000 ₫'), findsOneWidget);
    expect(find.text('45.000.000 ₫'), findsOneWidget);
    expect(find.text('Chỉ còn thiếu 44.000.000 ₫ để hoàn tất'), findsOneWidget);
    expect(find.textContaining('Cần nạp ~800.000'), findsOneWidget);
    expect(find.textContaining('Đang chậm so với kế hoạch'), findsOneWidget);
    expect(find.text('Lịch sử đóng góp'), findsOneWidget);
    expect(find.text('+2.000.000 ₫'), findsOneWidget);
    expect(find.text('28/10/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chưa có lần nạp nào: hiện trạng thái rỗng', (tester) async {
    await pump(tester, testGoal(), progress: _progress());
    expect(find.text('Chưa có lần nạp nào.'), findsOneWidget);
  });

  testWidgets('tải tiến độ lỗi: hiện thông điệp và Thử lại, phần hiện có/mục tiêu vẫn hiện', (tester) async {
    await pump(tester, testGoal());
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('45.000.000 ₫'), findsOneWidget);
  });

  testWidgets('nạp tiền: gọi controller với đúng số tiền; số 0 bị chặn', (tester) async {
    final mock = await pump(tester, testGoal(), progress: _progress());
    mock.nextResult = testGoal(current: 2000000);

    await tester.tap(find.text('Nạp tiền vào mục tiêu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Nạp tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
    expect(mock.contributions, isEmpty);

    await tester.enterText(find.byType(TextField), '1.000.000');
    await tester.tap(find.text('Nạp tiền'));
    await tester.pumpAndSettle();
    expect(mock.contributions.single, ('g1', BigInt.from(1000000)));
    expect(find.text('Đã nạp 1.000.000 ₫ vào mục tiêu thành công!'), findsOneWidget);
  });

  testWidgets('mục tiêu hoàn thành: khóa nút nạp tiền', (tester) async {
    await pump(tester, testGoal(status: 'completed', current: 45000000), progress: _progress());
    final button = tester.widget<ElevatedButton>(
      find.descendant(of: find.byKey(const ValueKey('contribute-goal')), matching: find.byType(ElevatedButton)),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Đã hoàn thành mục tiêu'), findsOneWidget);
  });

  testWidgets('nút sửa mở form sửa mục tiêu', (tester) async {
    await pump(tester, testGoal(), progress: _progress());
    await tester.tap(find.byKey(const ValueKey('edit-goal-detail')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa mục tiêu'), findsOneWidget);
  });
}
