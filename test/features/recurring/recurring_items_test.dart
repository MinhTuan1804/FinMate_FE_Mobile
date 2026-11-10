import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/recurring/data/recurring_items_repository.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import '../../fixtures/fixture.dart';

final _userId = StateProvider<String?>((ref) => 'u1');

void main() {
  test('RecurringItemEntity.fromJson đọc recurring_items.json thật', () {
    final list = (fixtureData('recurring_items') as List).map((e) => RecurringItemEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].direction, RecurringDirection.outflow);
    expect(list[0].name, 'Tiền nhà');
    expect(list[0].cadence, RecurringCadence.monthly);
    expect(list[0].status, RecurringStatus.active);
    expect(list[0].amountCents, BigInt.from(5000000));
    expect(list[1].direction, RecurringDirection.inflow);
    expect(list[1].status, RecurringStatus.suggested);
  });

  test('RecurringDirection/Cadence map hai chiều với API (PascalCase gửi đi, lowercase nhận về)', () {
    expect(RecurringDirection.inflow.apiValue, 'Inflow');
    expect(RecurringDirection.fromApi('outflow'), RecurringDirection.outflow);
    expect(RecurringCadence.yearly.apiValue, 'Yearly');
    expect(RecurringCadence.fromApi('weekly'), RecurringCadence.weekly);
  });

  group('RecurringItemsRepository', () {
    test('getItems không truyền status thì không gửi query, có thì gửi tên viết thường', () async {
      final adapter = RouteAdapter((o) => respondFixture('recurring_items'));
      final repo = RecurringItemsRepository(apiClient: testApiClient(adapter));

      await repo.getItems();
      expect(adapter.requests.single.queryParameters, isEmpty);

      await repo.getItems(status: RecurringStatus.active);
      expect(adapter.requests.last.queryParameters, {'status': 'active'});
    });

    test('createItem gửi direction/cadence PascalCase, nextDueDate yyyy-MM-dd, bỏ counterpartyName rỗng', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]}));
      final repo = RecurringItemsRepository(apiClient: testApiClient(adapter));

      await repo.createItem(
        direction: RecurringDirection.outflow,
        name: 'Tiền nhà',
        counterpartyName: '',
        amountCents: BigInt.from(5000000),
        cadence: RecurringCadence.monthly,
        nextDueDate: DateTime(2026, 12, 1),
      );

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/recurring-items');
      expect(req.data, {'direction': 'Outflow', 'name': 'Tiền nhà', 'amountCents': 5000000, 'cadence': 'Monthly', 'nextDueDate': '2026-12-01'});
    });

    test('createItem gửi counterpartyName/categoryId/financialAccountId khi có', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]}));
      final repo = RecurringItemsRepository(apiClient: testApiClient(adapter));

      await repo.createItem(
        direction: RecurringDirection.inflow,
        name: 'Lương',
        counterpartyName: 'Công ty ABC',
        amountCents: BigInt.from(20000000),
        cadence: RecurringCadence.monthly,
        nextDueDate: DateTime(2026, 12, 5),
        categoryId: 'cat-1',
        financialAccountId: 'acc-1',
      );

      final data = adapter.requests.single.data as Map;
      expect(data['counterpartyName'], 'Công ty ABC');
      expect(data['categoryId'], 'cat-1');
      expect(data['financialAccountId'], 'acc-1');
    });

    test('updateItem chỉ gửi trường được truyền (trường null giữ nguyên theo API)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]}));
      final repo = RecurringItemsRepository(apiClient: testApiClient(adapter));

      await repo.updateItem(id: 'r1', name: 'Tên mới', amountCents: BigInt.from(6000000));

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/recurring-items/r1');
      expect(req.data, {'name': 'Tên mới', 'amountCents': 6000000});
    });

    test('confirm/reject/pause/resume gọi đúng path POST', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]}));
      final repo = RecurringItemsRepository(apiClient: testApiClient(adapter));

      await repo.confirm('r1');
      await repo.reject('r1');
      await repo.pause('r1');
      await repo.resume('r1');

      expect(adapter.requests.map((r) => r.path), [
        '/api/v1/recurring-items/r1/confirm',
        '/api/v1/recurring-items/r1/reject',
        '/api/v1/recurring-items/r1/pause',
        '/api/v1/recurring-items/r1/resume',
      ]);
      expect(adapter.requests.every((r) => r.method == 'POST'), isTrue);
    });

    test('cancel gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = RecurringItemsRepository(apiClient: testApiClient(adapter));

      await repo.cancel('r1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/recurring-items/r1');
    });
  });

  group('recurringItemsControllerProvider', () {
    ProviderContainer build(RouteAdapter adapter) {
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(_userId)),
        recurringItemsRepositoryProvider.overrideWithValue(RecurringItemsRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('tải danh sách khi có người dùng; chưa đăng nhập thì rỗng và không gọi API', () async {
      final adapter = RouteAdapter((o) => respondFixture('recurring_items'));
      final userId = StateProvider<String?>((ref) => null);
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        recurringItemsRepositoryProvider.overrideWithValue(RecurringItemsRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      container.listen(recurringItemsControllerProvider, (_, __) {});
      await pumpEventQueue();
      expect(adapter.requests, isEmpty);
      expect(container.read(recurringItemsControllerProvider).value, isEmpty);

      container.read(userId.notifier).state = 'u1';
      await pumpEventQueue();
      expect(container.read(recurringItemsControllerProvider).value, hasLength(2));
    });

    test('create/update/confirm/reject/pause/resume/cancel đều tải lại danh sách', () async {
      var writes = 0;
      final adapter = RouteAdapter((o) {
        if (o.method != 'GET') {
          writes++;
          return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]});
        }
        return respondFixture('recurring_items');
      });
      final container = build(adapter);
      container.listen(recurringItemsControllerProvider, (_, __) {});
      await pumpEventQueue();
      final getsBefore = adapter.requests.where((r) => r.method == 'GET').length;

      final notifier = container.read(recurringItemsControllerProvider.notifier);
      await notifier.create(
        direction: RecurringDirection.outflow,
        name: 'Tiền nhà',
        amountCents: BigInt.from(5000000),
        cadence: RecurringCadence.monthly,
        nextDueDate: DateTime(2026, 12, 1),
      );
      await notifier.update(id: 'r1', name: 'Tên mới');
      await notifier.confirm('r2');
      await notifier.reject('r2');
      await notifier.pause('r1');
      await notifier.resume('r1');
      await notifier.cancel('r1');

      expect(writes, 7);
      final getsAfter = adapter.requests.where((r) => r.method == 'GET').length;
      expect(getsAfter, getsBefore + 7);
    });
  });
}
