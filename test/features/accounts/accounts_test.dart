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
    test('updateAccount gửi accountName mới và trả về tài khoản đã đổi tên', () async {
      final updated = {...(fixtureData('accounts') as List)[0] as Map<String, dynamic>, 'accountName': 'Vietcombank 2'};
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': updated}));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      final result = await repo.updateAccount(id: '78b154c6-c8d8-4b6d-9367-981772ce5382', name: 'Vietcombank 2');

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, contains('/financial-accounts/78b154c6-c8d8-4b6d-9367-981772ce5382'));
      expect(req.data, {'accountName': 'Vietcombank 2'});
      expect(result.name, 'Vietcombank 2');
    });

    test('toggleMonitoring gửi isMonitored và PATCH đúng path /monitoring', () async {
      final updated = {...(fixtureData('accounts') as List)[0] as Map<String, dynamic>, 'isMonitored': false};
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': updated}));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      final result = await repo.toggleMonitoring(id: '78b154c6-c8d8-4b6d-9367-981772ce5382', isMonitored: false);

      final req = adapter.requests.single;
      expect(req.path, contains('/financial-accounts/78b154c6-c8d8-4b6d-9367-981772ce5382/monitoring'));
      expect(req.data, {'isMonitored': false});
      expect(result.isMonitored, isFalse);
    });

    test('getBalance đọc đúng accountId/balanceCents/asOf', () async {
      final adapter = RouteAdapter((o) => respondFixture('account_balance'));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      final balance = await repo.getBalance('78b154c6-c8d8-4b6d-9367-981772ce5382');

      expect(adapter.requests.single.path, contains('/financial-accounts/78b154c6-c8d8-4b6d-9367-981772ce5382/balance'));
      expect(balance.accountId, '78b154c6-c8d8-4b6d-9367-981772ce5382');
      expect(balance.balanceCents, BigInt.from(31055000));
    });

    test('deleteAccount gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = AccountsRepository(apiClient: testApiClient(adapter));

      await repo.deleteAccount('78b154c6-c8d8-4b6d-9367-981772ce5382');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, contains('/financial-accounts/78b154c6-c8d8-4b6d-9367-981772ce5382'));
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
    test('rename gọi update rồi tải lại danh sách', () async {
      var patches = 0;
      final adapter = RouteAdapter((o) {
        if (o.method == 'PATCH') {
          patches++;
          final updated = {...(fixtureData('accounts') as List)[0] as Map<String, dynamic>, 'accountName': 'Tên mới'};
          return respondJson({'success': true, 'data': updated});
        }
        return respondFixture('accounts');
      });
      final container = build(adapter);
      container.listen(accountsControllerProvider, (_, __) {});
      await pumpEventQueue();

      await container.read(accountsControllerProvider.notifier).rename('78b154c6-c8d8-4b6d-9367-981772ce5382', 'Tên mới');

      expect(patches, 1);
      expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
    });

    test('setMonitoring gọi toggle rồi tải lại danh sách', () async {
      final adapter = RouteAdapter((o) {
        if (o.method == 'PATCH') {
          final updated = {...(fixtureData('accounts') as List)[1] as Map<String, dynamic>, 'isMonitored': false};
          return respondJson({'success': true, 'data': updated});
        }
        return respondFixture('accounts');
      });
      final container = build(adapter);
      container.listen(accountsControllerProvider, (_, __) {});
      await pumpEventQueue();

      await container.read(accountsControllerProvider.notifier).setMonitoring('ca6ba2c5-38ea-4af3-a664-a79a191a3ca7', false);

      expect(adapter.to('/monitoring'), hasLength(1));
      expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
    });

    test('delete gọi xóa rồi tải lại danh sách', () async {
      var deletes = 0;
      final adapter = RouteAdapter((o) {
        if (o.method == 'DELETE') {
          deletes++;
          return respondJson({'success': true, 'data': null});
        }
        return respondFixture('accounts');
      });
      final container = build(adapter);
      container.listen(accountsControllerProvider, (_, __) {});
      await pumpEventQueue();

      await container.read(accountsControllerProvider.notifier).delete('78b154c6-c8d8-4b6d-9367-981772ce5382');

      expect(deletes, 1);
      expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
    });

    test('getBalance trả thẳng kết quả từ repository, không tải lại danh sách', () async {
      var gets = 0;
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/balance')) return respondFixture('account_balance');
        gets++;
        return respondFixture('accounts');
      });
      final container = build(adapter);
      container.listen(accountsControllerProvider, (_, __) {});
      await pumpEventQueue();

      final balance = await container.read(accountsControllerProvider.notifier).getBalance('78b154c6-c8d8-4b6d-9367-981772ce5382');

      expect(balance.balanceCents, BigInt.from(31055000));
      expect(gets, 1);
    });
  });
}
