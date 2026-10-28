import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/data/planning_repository.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('PlanningRepository', () {
    test('getBudgets đọc ngân sách tổng và theo danh mục, gửi year/month', () async {
      final adapter = RouteAdapter((o) => respondFixture('budgets'));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      final result = await repo.getBudgets(month: 9, year: 2026);

      expect(adapter.requests.single.queryParameters, {'year': 2026, 'month': 9});
      expect(result.total!.limitAmountCents, BigInt.from(15000000));
      expect(result.categories.single.category, 'Ăn uống');
    });

    test('getBudgets khi chưa có ngân sách: total == null, danh sách rỗng (không dữ liệu mẫu)', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': true,
            'data': {'periodStart': '2026-09-01', 'periodEnd': '2026-10-01', 'totalBudget': null, 'categoryBudgets': []},
          }));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      final result = await repo.getBudgets(month: 9, year: 2026);

      expect(result.total, isNull);
      expect(result.categories, isEmpty);
    });

    test('mất mạng: ném NetworkException, KHÔNG trả dữ liệu mẫu', () async {
      final repo = PlanningRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))));

      await expectLater(repo.getBudgets(month: 9, year: 2026), throwsA(isA<NetworkException>()));
      await expectLater(repo.getGoals(), throwsA(isA<NetworkException>()));
    });

    test('createBudget ngân sách tổng chỉ gửi limitCents (số nguyên); theo danh mục có categoryId', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      await repo.createBudget(limitCents: BigInt.from(15000000));
      await repo.createBudget(categoryId: 'cat-1', limitCents: BigInt.from(6000000));

      expect(adapter.requests[0].data, {'limitCents': 15000000});
      expect(adapter.requests[1].data, {'categoryId': 'cat-1', 'limitCents': 6000000});
    });

    test('updateBudgetLimit gọi PATCH /budgets/{id}', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      await repo.updateBudgetLimit('b1', BigInt.from(2000000));

      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, '/api/v1/budgets/b1');
      expect(adapter.requests.single.data, {'limitCents': 2000000});
    });

    test('getGoals đọc saving_goals.json; createGoal gửi name/targetCents/deadline UTC', () async {
      final adapter = RouteAdapter((o) => o.method == 'GET'
          ? respondFixture('saving_goals')
          : respondJson({'success': true, 'data': (fixtureData('saving_goals') as List).first}));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      expect(await repo.getGoals(), hasLength(1));
      await repo.createGoal(name: 'Du lịch', targetCents: BigInt.from(30000000), deadline: DateTime.utc(2026, 11, 15));

      final post = adapter.requests.last;
      expect(post.path, '/api/v1/saving-goals');
      expect(post.data, {'name': 'Du lịch', 'targetCents': 30000000, 'deadline': '2026-11-15T00:00:00.000Z'});
    });

    test('contribute gửi amountCents tới /contribute và trả mục tiêu đã cập nhật (bỏ qua celebration)', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': true,
            'data': {
              'id': 'g1',
              'name': 'Quỹ',
              'targetCents': 45000000,
              'savedCents': 1000000,
              'status': 'active',
              'deadline': null,
              'celebration': {'leveledUp': true, 'level': 3, 'unlockedItemNames': ['Kính râm']},
            },
          }));
      final repo = PlanningRepository(apiClient: testApiClient(adapter));

      final result = await repo.contribute('g1', BigInt.from(1000000));

      expect(adapter.requests.single.path, '/api/v1/saving-goals/g1/contribute');
      expect(adapter.requests.single.data, {'amountCents': 1000000});
      expect(result.currentAmountCents, BigInt.from(1000000));
    });
  });

  group('PlanningController', () {
    test('tải ngân sách + mục tiêu; createOrUpdateBudget PATCH khi danh mục đã có ngân sách', () async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/budgets') && o.method == 'GET') return respondFixture('budgets');
        if (o.path.contains('/saving-goals')) return respondFixture('saving_goals');
        return respondJson({'success': true, 'data': null});
      });
      final userId = StateProvider<String?>((ref) => 'u1');
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        planningRepositoryProvider.overrideWithValue(PlanningRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      container.listen(planningControllerProvider, (_, __) {});
      await pumpEventQueue();

      final state = container.read(planningControllerProvider).value!;
      expect(state.overallBudget!.limitAmountCents, BigInt.from(15000000));
      expect(state.categoryBudgets, hasLength(1));
      expect(state.savingsGoals, hasLength(1));

      final foodId = state.categoryBudgets.first.categoryId;
      await container.read(planningControllerProvider.notifier).createOrUpdateBudget(categoryId: foodId, limitAmountCents: BigInt.from(7000000));

      final writes = adapter.requests.where((r) => r.method != 'GET').toList();
      expect(writes.single.method, 'PATCH');
      expect(writes.single.data, {'limitCents': 7000000});
    });

    test('chưa đăng nhập: không gọi API; đổi người dùng thì tải lại', () async {
      final adapter = RouteAdapter((o) => o.path.contains('/budgets') ? respondFixture('budgets') : respondFixture('saving_goals'));
      final userId = StateProvider<String?>((ref) => null);
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        planningRepositoryProvider.overrideWithValue(PlanningRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      container.listen(planningControllerProvider, (_, __) {});
      await pumpEventQueue();
      expect(adapter.requests, isEmpty);

      container.read(userId.notifier).state = 'u1';
      await pumpEventQueue();
      expect(adapter.requests, isNotEmpty);
    });
  });
}
