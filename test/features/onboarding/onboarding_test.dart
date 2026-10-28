import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:finmate/features/onboarding/presentation/screens/initial_setup_screen.dart';
import '../../fixtures/fixture.dart';

/// Backend giả có trạng thái: lưu các tài khoản đã tạo để kiểm tra tính idempotent.
class _FakeBackend {
  final List<Map<String, dynamic>> accounts = [];
  int failNextPostAt = -1; // chỉ số POST sẽ trả lỗi
  int posts = 0;

  RouteAdapter get adapter => RouteAdapter((o) {
        if (o.method == 'POST') {
          if (posts++ == failNextPostAt) {
            return respondJson({
              'success': false,
              'data': null,
              'error': {'code': 'FINANCIAL_ACCOUNT_PACKAGE_DUPLICATE', 'message': 'Trùng ứng dụng.'},
            }, status: 409);
          }
          final body = o.data as Map;
          final created = {
            'id': 'acc-${accounts.length}',
            'accountType': body['accountType'],
            'accountName': body['accountName'],
            'providerDisplayName': body['providerConfigId'] == null ? null : body['accountName'],
            'isMonitored': true,
            'balanceCents': body['initialBalanceCents'],
          };
          accounts.add(created);
          return respondJson({'success': true, 'data': created});
        }
        return respondJson({'success': true, 'data': accounts});
      });
}

AccountProviderInfo _provider(String key) => AccountProviderInfo.fromJson(
      (fixtureData('account_providers') as List).cast<Map<String, dynamic>>().firstWhere((p) => p['providerKey'] == key),
    );

void main() {
  late _FakeBackend backend;
  late AccountsController accounts;
  late List<int> incomeCalls;
  late List<BigInt> budgetCalls;
  late OnboardingController controller;

  setUp(() {
    backend = _FakeBackend();
    accounts = AccountsController(repository: AccountsRepository(apiClient: testApiClient(backend.adapter)), enabled: false);
    incomeCalls = [];
    budgetCalls = [];
    controller = OnboardingController(
      updateIncome: (v) async => incomeCalls.add(v),
      accounts: accounts,
      createTotalBudget: (v) async => budgetCalls.add(v),
    );
  });

  test('tạo ví tiền mặt và tài khoản cho provider được chọn, lưu thu nhập', () async {
    await controller.complete(OnboardingInput(
      monthlyIncomeCents: 15000000,
      cashBalanceCents: BigInt.from(500000),
      selectedProviders: [_provider('vietcombank')],
    ));

    expect(incomeCalls, [15000000]);
    expect(backend.accounts.map((a) => a['accountType']), ['Cash', 'Bank']);
    expect(backend.accounts.first['initialBalanceCents'] ?? backend.accounts.first['balanceCents'], 500000);
  });

  test('chạy lại không tạo trùng tài khoản (idempotent)', () async {
    final input = OnboardingInput(
      monthlyIncomeCents: 1000,
      cashBalanceCents: BigInt.zero,
      selectedProviders: [_provider('momo')],
    );

    await controller.complete(input);
    await controller.complete(input);

    expect(backend.accounts, hasLength(2));
  });

  test('có nhập ngân sách tháng thì tạo ngân sách tổng; bỏ trống thì không gọi', () async {
    await controller.complete(OnboardingInput(
      monthlyIncomeCents: 1000,
      cashBalanceCents: BigInt.zero,
      selectedProviders: const [],
      monthlyBudgetCents: BigInt.from(8000000),
    ));
    expect(budgetCalls, [BigInt.from(8000000)]);

    budgetCalls.clear();
    await controller.complete(OnboardingInput(monthlyIncomeCents: 1000, cashBalanceCents: BigInt.zero, selectedProviders: const []));
    expect(budgetCalls, isEmpty);
  });

  test('không chọn provider nào vẫn tạo ví tiền mặt', () async {
    await controller.complete(OnboardingInput(monthlyIncomeCents: 1000, cashBalanceCents: BigInt.zero, selectedProviders: const []));

    expect(backend.accounts.single['accountType'], 'Cash');
  });

  test('lỗi khi tạo tài khoản provider được ném lại (không nuốt)', () async {
    backend.failNextPostAt = 1; // POST thứ hai (provider) bị từ chối

    await expectLater(
      controller.complete(OnboardingInput(
        monthlyIncomeCents: 1000,
        cashBalanceCents: BigInt.zero,
        selectedProviders: [_provider('momo')],
      )),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FINANCIAL_ACCOUNT_PACKAGE_DUPLICATE')),
    );
  });

  testWidgets('bước chọn nguồn theo dõi hiển thị provider thật từ API, không danh sách cứng', (tester) async {
    final providers = (fixtureData('account_providers') as List)
        .map((e) => AccountProviderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [accountProvidersProvider.overrideWith((ref) async => providers)],
      child: const MaterialApp(home: InitialSetupScreen()),
    ));

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('MB Bank'), findsOneWidget);
    expect(find.text('ZaloPay'), findsOneWidget);
    expect(find.text('Techcombank'), findsNothing); // tên cứng cũ, không có trong backend
  });
}
