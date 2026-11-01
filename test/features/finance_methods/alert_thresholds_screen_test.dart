import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/screens/alert_thresholds_screen.dart';
import 'fake_finance_repository.dart';

Future<void> pumpScreen(WidgetTester tester, FakeFinanceRepository repository) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [financeMethodsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: AlertThresholdsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

ElevatedButton saveButton(WidgetTester tester) => tester.widget<ElevatedButton>(find.byKey(const Key('save_thresholds')));

void main() {
  group('chưa có ngưỡng nào: dùng mặc định của hệ thống nhưng vẫn chỉnh được', () {
    testWidgets('hiện ngưỡng mặc định và nguồn; chưa sửa thì chưa lưu được; chưa có nút "dùng mặc định"', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpScreen(tester, repository);

      final system = repository.thresholds.systemDefault;
      expect(tester.widget<Text>(find.byKey(const Key('value_t1'))).data, '${system.t1}%');
      expect(tester.widget<Text>(find.byKey(const Key('value_t2'))).data, '${system.t2}%');
      expect(find.text('Theo mặc định của FinMate'), findsOneWidget);
      expect(find.text('100% (cố định)'), findsOneWidget);
      expect(find.byKey(const Key('threshold_editor')), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('reset_thresholds')), findsNothing);
    });

    testWidgets('sửa rồi lưu: gửi đúng cặp số, màn hiện nguồn cá nhân và có nút quay về mặc định', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(find.byKey(const Key('threshold_t1')), '50');
      await tester.enterText(find.byKey(const Key('threshold_t2')), '80');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('save_thresholds')));
      await tester.pumpAndSettle();

      expect(repository.savedThresholds, [const ThresholdPair(50, 80)]);
      expect(find.text('Theo cài đặt của bạn'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('value_t1'))).data, '50%');
      expect(find.byKey(const Key('reset_thresholds')), findsOneWidget);
    });

    testWidgets('T1 không nhỏ hơn T2: báo ngay dưới ô và KHÔNG gửi gì lên backend', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(find.byKey(const Key('threshold_t1')), '90');
      await tester.enterText(find.byKey(const Key('threshold_t2')), '60');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save_thresholds')));
      await tester.pumpAndSettle();

      expect(find.text('Phải lớn hơn ngưỡng nhắc nhẹ'), findsOneWidget);
      expect(repository.savedThresholds, isEmpty);
    });

    testWidgets('chỉ nhập được chữ số; số ngoài khoảng bị chặn', (tester) async {
      final repository = FakeFinanceRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(find.byKey(const Key('threshold_t2')), '100');
      await tester.pump();

      expect(find.text('Từ 2% đến 99%'), findsWidgets);
      await tester.enterText(find.byKey(const Key('threshold_t1')), '5a');
      expect(tester.widget<TextFormField>(find.byKey(const Key('threshold_t1'))).controller!.text, '5');
    });

    testWidgets('backend từ chối: hiện lỗi của backend ngay trên màn, không đổi ngưỡng đang hiển thị', (tester) async {
      final repository = FakeFinanceRepository(thresholdError: BusinessRuleException(code: 'ALERT_THRESHOLD_INVALID', message: 'Ngưỡng không hợp lệ.'));
      await pumpScreen(tester, repository);

      await tester.enterText(find.byKey(const Key('threshold_t1')), '50');
      await tester.enterText(find.byKey(const Key('threshold_t2')), '80');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save_thresholds')));
      await tester.pumpAndSettle();

      expect(find.text('Ngưỡng không hợp lệ.'), findsOneWidget);
      expect(find.text('Theo mặc định của FinMate'), findsOneWidget);
    });
  });

  group('đã đặt ngưỡng cá nhân', () {
    testWidgets('quay về mặc định: gọi xóa rồi hiện lại nguồn hệ thống', (tester) async {
      final repository = FakeFinanceRepository(thresholds: thresholdsFixture('personal'));
      await pumpScreen(tester, repository);

      expect(find.text('Theo cài đặt của bạn'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reset_thresholds')));
      await tester.pumpAndSettle();

      expect(repository.clearedThresholds, 1);
      expect(find.text('Theo mặc định của FinMate'), findsOneWidget);
      expect(find.byKey(const Key('reset_thresholds')), findsNothing);
    });
  });

  group('đang dùng cách quản lý có ngưỡng riêng', () {
    testWidgets('không cho chỉnh ở đây: chỉ chỉ đường tới Cách quản lý của tôi và nhắc ngưỡng cá nhân vẫn được giữ', (tester) async {
      final repository = FakeFinanceRepository(thresholds: thresholdsFixture('method'));
      await pumpScreen(tester, repository);

      final settings = repository.thresholds;
      expect(find.byKey(const Key('threshold_editor')), findsNothing);
      expect(find.byKey(const Key('method_notice')), findsOneWidget);
      expect(find.byKey(const Key('open_my_methods')), findsOneWidget);
      expect(find.textContaining(settings.methodName!), findsWidgets);
      expect(find.textContaining('${settings.personal!.t1}% / ${settings.personal!.t2}%'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('value_t1'))).data, '${settings.effective.t1}%');
    });
  });
}
