import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

final _userId = StateProvider<String?>((ref) => 'u1');

void main() {
  test('FinancialAccount.fromJson đọc accounts.json thật', () {
    final list = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].type, AccountType.bank);
    expect(list[0].name, 'Vietcombank');
    expect(list[0].providerName, 'Vietcombank');
    expect(list[0].balanceCents, BigInt.from(30955000));
    expect(list[1].type, AccountType.cash);
    expect(list[1].providerName, isNull);
    expect(list[1].isMonitored, isTrue);
  });

  test('FinancialAccount.fromJson_reads_packageName', () {
    final list = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();

    expect(list[0].packageName, 'com.VCB');
    expect(list[1].packageName, isNull);
  });

  test('AccountType map hai chiều với API và có nhãn tiếng Việt', () {
    expect(AccountType.fromApi('EWallet'), AccountType.eWallet);
    expect(AccountType.eWallet.apiValue, 'EWallet');
    expect(AccountType.cash.label, 'Tiền mặt');
  });

  test('AccountProviderInfo.fromJson đọc 5 provider thật', () {
    final list = (fixtureData('account_providers') as List).map((e) => AccountProviderInfo.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(5));
    expect(list.first.providerKey, 'mb_bank');
    expect(list.first.type, AccountType.bank);
    expect(list.firstWhere((p) => p.providerKey == 'momo').type, AccountType.eWallet);
  });

  group('AccountsRepository', () {
    test('createAccount ví tiền mặt không gửi providerConfigId', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('accounts') as List)[1]}));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      final created = await repo.createAccount(name: 'Ví tiền mặt', type: AccountType.cash, initialBalanceCents: BigInt.from(5000000));

      final req = adapter.to('/financial-accounts').single;
      expect(req.method, 'POST');
      expect(req.data, {'accountName': 'Ví tiền mặt', 'accountType': 'Cash', 'initialBalanceCents': 5000000});
      expect(created.type, AccountType.cash);
    });

    test('createAccount gửi providerConfigId khi có', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('accounts') as List)[0]}));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      await repo.createAccount(name: 'Vietcombank', type: AccountType.bank, providerConfigId: 'p1');

      expect((adapter.requests.single.data as Map)['providerConfigId'], 'p1');
      expect((adapter.requests.single.data as Map)['initialBalanceCents'], 0);
    });

    test('lỗi trùng provider được ném lại nguyên thông điệp của server', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': false,
            'data': null,
            'error': {'code': 'FINANCIAL_ACCOUNT_PACKAGE_DUPLICATE', 'message': 'Bạn đã có tài khoản khác theo dõi ứng dụng này.'},
          }, status: 409));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.createAccount(name: 'X', type: AccountType.bank, providerConfigId: 'p1'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FINANCIAL_ACCOUNT_PACKAGE_DUPLICATE')),
      );
    });
  });

  group('accountsControllerProvider', () {
    ProviderContainer build(RouteAdapter adapter) {
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(_userId)),
        accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('tải danh sách tài khoản khi có người dùng', () async {
      final container = build(RouteAdapter((o) => respondFixture('accounts')));
      container.listen(accountsControllerProvider, (_, __) {});

      await pumpEventQueue();

      expect(container.read(accountsControllerProvider).value, hasLength(2));
    });

    test('đổi người dùng thì tạo lại và tải lại; đăng xuất thì trống và không gọi API', () async {
      final adapter = RouteAdapter((o) => respondFixture('accounts'));
      final container = build(adapter);
      container.listen(accountsControllerProvider, (_, __) {});
      await pumpEventQueue();
      expect(adapter.to('/financial-accounts'), hasLength(1));

      container.read(_userId.notifier).state = 'u2';
      await pumpEventQueue();
      expect(adapter.to('/financial-accounts'), hasLength(2));

      container.read(_userId.notifier).state = null;
      await pumpEventQueue();
      expect(adapter.to('/financial-accounts'), hasLength(2));
      expect(container.read(accountsControllerProvider).value, isEmpty);
    });

    test('create ném lỗi lại và tải lại danh sách khi thành công', () async {
      var posts = 0;
      final adapter = RouteAdapter((o) {
        if (o.method == 'POST') {
          posts++;
          return respondJson({'success': true, 'data': (fixtureData('accounts') as List)[1]});
        }
        return respondFixture('accounts');
      });
      final container = build(adapter);
      container.listen(accountsControllerProvider, (_, __) {});
      await pumpEventQueue();

      await container.read(accountsControllerProvider.notifier).create(name: 'Ví', type: AccountType.cash);

      expect(posts, 1);
      expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
    });
  });
}
