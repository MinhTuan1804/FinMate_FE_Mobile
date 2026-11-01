import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_providers.dart';
import 'package:finmate/features/finance_methods/presentation/screens/my_methods_screen.dart';
import 'package:finmate/features/finance_methods/presentation/widgets/method_home_section.dart';
import 'fake_finance_repository.dart';

class _MockAuthController extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  _MockAuthController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _user({int? income}) => UserProfile(
      id: 'usr-1',
      email: 'a@finmate.local',
      displayName: 'A',
      monthlyIncomeCents: income,
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime(2026, 11, 1),
    );

/// Nhãn khối được viết hoa khi vẽ.
String _label(String text) => text.toUpperCase();

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required List<UserMethod> methods,
    SpendableInfo? spendable,
    List<GoalSuggestion>? suggestions,
    int? income = 20000000,
    Survey? survey,
    List<JarSet>? jars,
    Future<List<UserMethod>> Function()? loadMethods,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _MockAuthController(AsyncValue.data(_user(income: income)))),
          myMethodsProvider.overrideWith((ref) => (loadMethods ?? () async => methods)()),
          spendableProvider.overrideWith((ref) async => spendable ?? sampleSpendable()),
          goalSuggestionsProvider.overrideWith((ref) async => suggestions ?? sampleSuggestions()),
          surveyProvider.overrideWith((ref) async => survey ?? pendingSurvey()),
          jarsProvider.overrideWith((ref) async => jars ?? const <JarSet>[]),
        ],
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FinanceHomeSection()))),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('mỗi cách quản lý một trang chủ', () {
    testWidgets('ngân sách theo nhóm: chia thu nhập thành 3 thanh kèm % và số tiền, ngưỡng cảnh báo, tiền còn được chi', (tester) async {
      await pumpSection(tester, methods: [userMethodOf('category_budget')]);

      expect(find.text(_label('Chia thu nhập')), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      // 20.000.000 ₫ x 50 / 30 / 20 %
      expect(find.text('10.000.000 ₫'), findsOneWidget);
      expect(find.text('6.000.000 ₫'), findsOneWidget);
      expect(find.text('4.000.000 ₫'), findsOneWidget);
      expect(find.text('Tổng 100% thu nhập.'), findsOneWidget);

      expect(find.text(_label('Ngưỡng cảnh báo')), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('spendable_amount'))).data, '20.000.000 ₫');
    });

    testWidgets('theo dõi tối giản: KHÔNG có tiền khả dụng, có các bước bắt đầu — khác hẳn ngân sách theo nhóm', (tester) async {
      await pumpSection(tester, methods: [userMethodOf('minimal_tracking')]);

      expect(find.byKey(const Key('spendable_amount')), findsNothing);
      expect(find.byKey(const Key('block_starter_steps')), findsOneWidget);
      expect(find.text(_label('Chia thu nhập')), findsNothing);
      for (final step in userMethodOf('minimal_tracking').method.starterSteps) {
        expect(find.text(step), findsOneWidget);
      }
    });

    testWidgets('khối lạ mà app chưa biết vẽ bị bỏ qua, các khối còn lại vẫn hiện', (tester) async {
      final base = userMethodOf('minimal_tracking');
      final method = FinanceMethod(
        code: base.method.code,
        name: base.method.name,
        summary: base.method.summary,
        role: base.method.role,
        goalMode: base.method.goalMode,
        whyText: base.method.whyText,
        starterSteps: base.method.starterSteps,
        params: base.method.params,
        homeLayout: const [HomeBlock(type: 'hologram'), HomeBlock(type: HomeBlock.starterSteps)],
      );
      final userMethod = UserMethod(id: base.id, method: method, role: 'primary', chosenVia: 'x', overrides: const {}, effective: base.effective);

      await pumpSection(tester, methods: [userMethod]);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('block_starter_steps')), findsOneWidget);
    });

    testWidgets('cách bổ trợ gập lại; mở ra mới thấy các khối của nó', (tester) async {
      await pumpSection(tester, methods: [userMethodOf('category_budget'), userMethodOf('goal_fund', role: 'supporting')]);

      expect(find.byKey(const Key('method_home_category_budget')), findsOneWidget);
      expect(find.byKey(const Key('method_home_goal_fund')), findsOneWidget);
      expect(find.byKey(const Key('block_starter_steps')), findsNothing, reason: 'cách bổ trợ đang gập');

      await tester.tap(find.text('Quỹ mục tiêu và trả cho mình trước'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('block_starter_steps')), findsOneWidget);
    });
  });

  group('không bịa số', () {
    testWidgets('chưa khai thu nhập: không hiện số tiền còn được chi, không tính số tiền cho từng thanh', (tester) async {
      const spendable = SpendableInfo(goalMode: 'reserve_first', incomeCents: null, spentCents: 0, goalSetAsideCents: 0, spendableCents: null, goals: []);
      await pumpSection(tester, methods: [userMethodOf('category_budget')], spendable: spendable, income: null);

      expect(find.byKey(const Key('spendable_amount')), findsNothing);
      expect(find.textContaining('Hãy nhập thu nhập hàng tháng'), findsOneWidget);
      expect(find.textContaining('Nhập thu nhập hàng tháng để xem số tiền'), findsOneWidget);
      expect(find.text('10.000.000 ₫'), findsNothing);
    });

    testWidgets('đã chi vượt: số còn được chi âm hiện đúng, không làm tròn về 0', (tester) async {
      const spendable = SpendableInfo(goalMode: 'reserve_first', incomeCents: 20000000, spentCents: 21000000, goalSetAsideCents: 0, spendableCents: -1000000, goals: []);
      await pumpSection(tester, methods: [userMethodOf('category_budget')], spendable: spendable);

      expect(tester.widget<Text>(find.byKey(const Key('spendable_amount'))).data, '-1.000.000 ₫');
    });
  });

  group('mục tiêu', () {
    testWidgets('có mục tiêu đang dành tiền: hiện tiến độ trong tháng', (tester) async {
      const spendable = SpendableInfo(
        goalMode: 'reserve_first',
        incomeCents: 20000000,
        spentCents: 0,
        goalSetAsideCents: 2000000,
        spendableCents: 18000000,
        goals: [SpendableGoal(goalId: 'g1', name: 'Mua laptop', requiredPerMonthCents: 4000000, depositedThisMonthCents: 1000000, setAsideCents: 2000000)],
      );
      await pumpSection(tester, methods: [userMethodOf('category_budget')], spendable: spendable);

      expect(find.text('Mua laptop'), findsOneWidget);
      expect(find.text('Đã dành 1.000.000 ₫ / 4.000.000 ₫ tháng này'), findsOneWidget);
    });

    testWidgets('mục tiêu đòi dành nhiều hơn thu nhập: báo chưa khả thi, số được chi KHÔNG bị âm theo mục tiêu đó', (tester) async {
      // Số thật của một người dùng: thu nhập 8 triệu, mục tiêu cần 166.666.667 ₫ mỗi tháng. Backend vẫn trả -158.666.667 vì cộng cả khoản đó.
      const spendable = SpendableInfo(
        goalMode: 'envelope',
        incomeCents: 8000000,
        spentCents: 0,
        goalSetAsideCents: 166666667,
        spendableCents: -158666667,
        goals: [SpendableGoal(goalId: 'g1', name: 'Mua', requiredPerMonthCents: 166666667, depositedThisMonthCents: 0, setAsideCents: 166666667)],
      );
      await pumpSection(tester, methods: [userMethodOf('category_budget')], spendable: spendable);

      expect(find.text('Mục tiêu "Mua" chưa khả thi'), findsOneWidget);
      expect(find.textContaining('166.666.667 ₫ mỗi tháng, trong khi thu nhập chỉ 8.000.000 ₫'), findsOneWidget);
      expect(find.text('Sửa mục tiêu'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('spendable_amount'))).data, '8.000.000 ₫');
      expect(find.byKey(const Key('spendable_excludes_goals')), findsOneWidget);
      expect(find.text('Cần 166.666.667 ₫ mỗi tháng, vượt thu nhập của bạn'), findsOneWidget);
      expect(find.text('Dành cho mục tiêu'), findsNothing, reason: 'khoản không thể đạt không được coi là đã dành');
    });

    testWidgets('mục tiêu khả thi: không có cảnh báo, số được chi vẫn trừ khoản dành cho mục tiêu', (tester) async {
      const spendable = SpendableInfo(
        goalMode: 'reserve_first',
        incomeCents: 20000000,
        spentCents: 0,
        goalSetAsideCents: 2000000,
        spendableCents: 18000000,
        goals: [SpendableGoal(goalId: 'g1', name: 'Mua laptop', requiredPerMonthCents: 4000000, depositedThisMonthCents: 2000000, setAsideCents: 2000000)],
      );
      await pumpSection(tester, methods: [userMethodOf('category_budget')], spendable: spendable);

      expect(find.textContaining('chưa khả thi'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('spendable_amount'))).data, '18.000.000 ₫');
      expect(find.text('Dành cho mục tiêu'), findsOneWidget);
    });

    testWidgets('chưa có mục tiêu: gợi ý mẫu mục tiêu của backend', (tester) async {
      await pumpSection(tester, methods: [userMethodOf('category_budget')]);

      expect(find.text(sampleSuggestions().first.name), findsOneWidget);
    });
  });

  group('khối hũ: chi tiêu tháng này theo danh mục so với phần thu nhập được chia', () {
    Jar jar({String key = 'j', String label = 'Hũ', int pct = 30, int? allocated, int spent = 0, int? used, String level = 'ok'}) => Jar(
          key: key,
          label: label,
          allocationPct: pct,
          allocatedCents: allocated,
          spentCents: spent,
          remainingCents: allocated == null ? null : allocated - spent,
          usedPct: used,
          level: level,
          categories: const [],
        );

    JarSet setOf(List<Jar> jars, {int? income = 20000000, int unassigned = 0}) => JarSet(
          userMethodId: userMethodWithJars().id,
          methodCode: 'category_budget',
          title: null,
          incomeCents: income,
          jars: jars,
          unassignedSpentCents: unassigned,
        );

    testWidgets('dữ liệu thật: ba hũ kèm số đã chi, số được chia, mức dùng và chi tiêu ngoài hũ', (tester) async {
      await pumpSection(tester, methods: [userMethodWithJars()], jars: jarSetsFixture());

      expect(find.byKey(const Key('block_jars')), findsOneWidget);
      expect(find.text('Nhu cầu'), findsOneWidget);
      expect(find.text('Mong muốn'), findsOneWidget);
      expect(find.text('Mục tiêu'), findsWidgets);
      expect(find.text('Đã dùng 23%'), findsOneWidget);
      expect(find.text('Đã dùng 90%'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('jar_amount_needs_pct'))).data, 'Đã chi 2.300.000 ₫ / 10.000.000 ₫');
      expect(find.text('Còn 7.700.000 ₫'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('jars_unassigned'))).data, startsWith('Ngoài các hũ: 500.000 ₫'));
    });

    testWidgets('hũ chạm ngưỡng cảnh báo được nói bằng chữ, không chỉ bằng màu; hũ còn dư thì không có cảnh báo', (tester) async {
      await pumpSection(tester, methods: [userMethodWithJars()], jars: jarSetsFixture());

      expect(tester.widget<Text>(find.byKey(const Key('jar_status_wants_pct'))).data, 'Sắp cạn hũ');
      expect(find.byKey(const Key('jar_status_needs_pct')), findsNothing);
    });

    testWidgets('chi vượt hũ: báo "Đã vượt hũ" và số vượt', (tester) async {
      final over = jar(key: 'a', label: 'Giải trí', pct: 10, allocated: 2000000, spent: 2600000, used: 130, level: 'over');
      await pumpSection(tester, methods: [userMethodWithJars()], jars: [setOf([over])]);

      expect(find.text('Đã vượt hũ'), findsOneWidget);
      expect(find.text('Vượt 600.000 ₫'), findsOneWidget);
    });

    testWidgets('chưa khai thu nhập: chỉ hiện số đã chi, không bịa số được chia', (tester) async {
      final unknown = jar(key: 'a', label: 'Nhu cầu', pct: 50, spent: 800000, level: 'none');
      await pumpSection(tester, methods: [userMethodWithJars()], jars: [setOf([unknown], income: null)]);

      expect(tester.widget<Text>(find.byKey(const Key('jar_amount_a'))).data, 'Đã chi 800.000 ₫');
      expect(find.textContaining('Còn '), findsNothing);
      expect(find.byKey(const Key('jar_used_a')), findsNothing);
      expect(find.textContaining('Nhập thu nhập hàng tháng để xem số tiền được chia'), findsOneWidget);
    });

    testWidgets('không có dữ liệu hũ cho cách này: khối ẩn, các khối khác vẫn vẽ', (tester) async {
      await pumpSection(tester, methods: [userMethodWithJars()], jars: const []);

      expect(find.byKey(const Key('jar_needs_pct')), findsNothing);
      expect(find.byKey(const Key('block_spendable')), findsOneWidget);
    });
  });

  group('admin đã tắt cách đang dùng: báo và mời chọn lại, không gỡ', () {
    testWidgets('trang chủ hiện thông báo kèm lối chọn cách khác, các khối của cách đó vẫn vẽ như cũ', (tester) async {
      final userMethod = unavailableUserMethods().single;
      await pumpSection(tester, methods: [userMethod]);

      expect(find.byKey(Key('unavailable_notice_${userMethod.method.code}')), findsOneWidget);
      expect(find.textContaining(userMethod.method.name), findsWidgets);
      expect(find.text('Xem gợi ý cách khác'), findsOneWidget);
      expect(find.byKey(const Key('block_starter_steps')), findsOneWidget, reason: 'người dùng vẫn thấy trang chủ của cách họ đang dùng');
    });

    testWidgets('cách còn cung cấp thì không có thông báo', (tester) async {
      await pumpSection(tester, methods: [userMethodOf('category_budget')]);

      expect(find.byKey(const Key('unavailable_notice_category_budget')), findsNothing);
      expect(find.text('Xem gợi ý cách khác'), findsNothing);
    });

    testWidgets('màn "Cách quản lý của tôi" ghi rõ cách đã ngừng cung cấp', (tester) async {
      final userMethod = unavailableUserMethods().single;
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [myMethodsProvider.overrideWith((ref) async => [userMethod])],
          child: const MaterialApp(home: MyMethodsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('unavailable_${userMethod.method.code}')), findsOneWidget);
      expect(find.text('Đã ngừng cung cấp'), findsOneWidget);
    });
  });

  group('chưa dùng cách nào / lỗi', () {
    testWidgets('mời làm khảo sát khi chưa trả lời', (tester) async {
      await pumpSection(tester, methods: const []);

      expect(find.byKey(const Key('choose_method_card')), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);
    });

    testWidgets('đã làm khảo sát rồi thì mời xem gợi ý', (tester) async {
      final done = Survey(status: 'completed', questions: const [], answers: const [SurveyAnswer('income_pattern', 'A')]);
      await pumpSection(tester, methods: const [], survey: done);

      expect(find.text('Xem gợi ý'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsNothing);
    });

    testWidgets('lỗi tải: báo lỗi và có nút Thử lại, không hiện số', (tester) async {
      await pumpSection(tester, methods: const [], loadMethods: () async => throw Exception('Không có kết nối mạng'));

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    });
  });
}
