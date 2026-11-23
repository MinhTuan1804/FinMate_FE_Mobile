import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b8_financial_plan_screen.dart';
import '../../fixtures/fixture.dart';

const _foodId = '11111111-1111-1111-1111-111111111111';
const _housingId = '22222222-2222-2222-2222-222222222222';
const _shoppingId = '33333333-3333-3333-3333-333333333333';

/// Bản nháp như backend trả cho: thu 10tr, nhà 2,5tr, ăn uống khai 2,5tr bị co còn 2tr, mua sắm 0 (không gửi khi áp dụng).
/// Số dư = thu − tổng hạn mức (4.500.000) − trả nợ [fixedOther], khớp cách backend tính.
Map<String, dynamic> _draft({int fixedOther = 0, List<String> warnings = const []}) => {
      'success': true,
      'error': null,
      'meta': null,
      'data': {
        'methodCode': 'category_budget',
        'methodVersion': 1,
        'incomeVnd': 10000000,
        'fixedVnd': 2500000,
        'fixedOtherVnd': fixedOther,
        'plannedSpendVnd': 4500000 + fixedOther,
        'surplusVnd': 5500000 - fixedOther,
        'saveTargetVnd': 2000000,
        'savingsBalanceVnd': null,
        'warnings': warnings,
        'warningTexts': {'deficit': 'Chữ thâm hụt từ cấu hình', 'below_save_target': 'Chữ để dành từ cấu hình'},
        'groups': [
          {'key': 'needs_pct', 'label': 'Nhu cầu', 'kind': 'spend', 'pct': 50, 'capVnd': 4500000},
          {'key': 'goals_pct', 'label': 'Mục tiêu', 'kind': 'save', 'pct': 20, 'capVnd': null},
        ],
        'categories': [
          {'categoryId': _housingId, 'slug': 'housing', 'name': 'Nhà ở', 'groupKey': 'needs_pct', 'fixedVnd': 2500000, 'declaredVnd': 2500000, 'limitVnd': 2500000, 'reducedByVnd': 0},
          {'categoryId': _foodId, 'slug': 'food', 'name': 'Ăn uống', 'groupKey': 'needs_pct', 'fixedVnd': 0, 'declaredVnd': 2500000, 'limitVnd': 2000000, 'reducedByVnd': 500000},
          {'categoryId': _shoppingId, 'slug': 'shopping', 'name': 'Mua sắm', 'groupKey': 'wants_pct', 'fixedVnd': 0, 'declaredVnd': 0, 'limitVnd': 0, 'reducedByVnd': 0},
        ],
      },
    };


Map<String, dynamic> _error(String code) => {
      'success': false,
      'data': null,
      'meta': null,
      'error': {'code': code, 'message': 'Lỗi', 'details': null},
    };

Future<RouteAdapter> _pump(WidgetTester tester, {Map<String, dynamic>? draft, int status = 200, bool incomeFixesIt = false}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var incomeSaved = false;
  final adapter = RouteAdapter((o) {
    if (o.path.contains('/categories/apply')) {
      return respondJson({'success': true, 'data': [], 'error': null, 'meta': null});
    }
    if (o.path.contains('/users/me')) {
      if (o.method == 'PATCH') incomeSaved = true;
      return respondJson({
        'success': true,
        'error': null,
        'meta': null,
        'data': {'id': 'u1', 'email': 'a@b.c', 'displayName': 'Tuấn', 'monthlyIncomeCents': incomeSaved ? 10000000 : null},
      });
    }
    if (incomeFixesIt && incomeSaved) return respondJson(_draft());
    return respondJson(draft ?? _draft(), status: status);
  });
  final router = GoRouter(initialLocation: '/plan', routes: [
    GoRoute(path: '/plan', builder: (_, __) => const FinancialPlanScreen()),
    GoRoute(path: '/finance-methods/my-methods', builder: (_, __) => const Text('my-methods')),
    GoRoute(path: '/survey', builder: (_, __) => const Text('survey')),
    GoRoute(path: '/finance-methods', builder: (_, __) => const Text('recommendations')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

Finder _limitField(String slug) => find.descendant(
      of: find.byKey(ValueKey('plan-limit-$slug')),
      matching: find.byType(TextFormField),
    );

void main() {
  group('FinancialPlanScreen (B8)', () {
    testWidgets('hiện dòng tổng thu → cố định → chi → dư và hạn mức từng danh mục', (tester) async {
      await _pump(tester);

      expect(find.text('10.000.000 ₫'), findsOneWidget);
      expect(find.text('2.500.000 ₫'), findsWidgets);
      expect(find.byKey(const ValueKey('plan-surplus')), findsOneWidget);
      expect(find.text('5.500.000 ₫'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Đã giảm 500.000 ₫ so với mức bạn khai'), findsOneWidget);
    });

    testWidgets('sửa hạn mức thì số dư tính lại ngay trên máy', (tester) async {
      await _pump(tester);

      await tester.enterText(_limitField('food'), '1500000');
      await tester.pumpAndSettle();

      expect(find.text('6.000.000 ₫'), findsOneWidget);
    });

    testWidgets('thâm hụt: hiện lời khuyên (chữ từ cấu hình backend), không hiện mục tiêu để dành', (tester) async {
      await _pump(tester, draft: _draft(fixedOther: 6500000, warnings: ['deficit']));

      expect(find.byKey(const ValueKey('plan-warning-deficit')), findsOneWidget);
      expect(find.text('Chữ thâm hụt từ cấu hình'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-save-target')), findsNothing);
    });

    testWidgets('chưa có thu nhập: nhập ngay trên màn, lưu vào hồ sơ rồi kế hoạch tải lại', (tester) async {
      final adapter = await _pump(tester, draft: _error('FINANCE_PLAN_NO_INCOME'), status: 422, incomeFixesIt: true);

      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('plan-income')), matching: find.byType(TextFormField)),
        '10000000',
      );
      await tester.tap(find.byKey(const ValueKey('plan-save-income')));
      await tester.pumpAndSettle();

      final patch = adapter.to('/users/me').where((r) => r.method == 'PATCH').single;
      final body = (patch.data is String ? jsonDecode(patch.data as String) : patch.data) as Map<String, dynamic>;
      expect(body, {'displayName': 'Tuấn', 'monthlyIncomeCents': 10000000});
      expect(find.byKey(const ValueKey('plan-surplus')), findsOneWidget, reason: 'kế hoạch tải lại sau khi có thu nhập');
    });

    testWidgets('Áp dụng gửi các dòng hạn mức > 0 rồi sang màn cách quản lý', (tester) async {
      final adapter = await _pump(tester);

      await tester.enterText(_limitField('food'), '1500000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-apply')));
      await tester.pumpAndSettle();

      final request = adapter.to('/categories/apply').single;
      final body = (request.data is String ? jsonDecode(request.data as String) : request.data) as Map<String, dynamic>;
      expect(body['items'], [
        {'categoryId': _housingId, 'limitCents': 2500000},
        {'categoryId': _foodId, 'limitCents': 1500000},
      ]);
      expect(find.text('my-methods'), findsOneWidget);
    });

    testWidgets('Để sau không gửi gì', (tester) async {
      final adapter = await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('plan-later')));
      await tester.pumpAndSettle();

      expect(adapter.to('/categories/apply'), isEmpty);
      expect(find.text('my-methods'), findsOneWidget);
    });
  });
}
