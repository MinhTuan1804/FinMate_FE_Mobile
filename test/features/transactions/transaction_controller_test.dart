import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _tx(String id, String type, {String cat = 'Ăn uống'}) => {
      'id': id,
      'financialAccountId': 'acc-1',
      'counterAccountId': null,
      'categoryId': 'cat-1',
      'categoryName': cat,
      'amountCents': 1000,
      'transactionType': type,
      'source': 'Manual',
      'status': 'Confirmed',
      'merchantName': null,
      'description': id,
      'transactedAt': '2026-09-30T05:00:00+00:00',
      'balanceAfterCents': 0,
      'createdAt': '2026-09-30T05:00:00+00:00',
    };

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  TransactionController build(RouteAdapter adapter, {bool enabled = true, void Function()? onDataChanged}) {
    final api = testApiClient(adapter);
    return TransactionController(
      repository: TransactionRepository(apiClient: api, database: db),
      syncService: SyncService(db: db, apiClient: api),
      enabled: enabled,
      onDataChanged: onDataChanged,
    );
  }

  test('setFilter gửi type lên server và thay danh sách', () async {
    final adapter = RouteAdapter((o) {
      final type = o.queryParameters['type'];
      return respondJson({
        'success': true,
        'data': type == 'Debit' ? [_tx('e1', 'Debit')] : [_tx('e1', 'Debit'), _tx('i1', 'Credit')],
        'meta': {'cursor': null},
      });
    });
    final c = build(adapter);
    await pumpEventQueue();
    expect(c.state.value, hasLength(2));

    await c.setFilter(TransactionType.expense);

    expect(adapter.requests.last.queryParameters['type'], 'Debit');
    expect(c.state.value!.map((t) => t.id), ['e1']);
    expect(c.filter, TransactionType.expense);
  });

  test('loadMore nối trang kế tiếp; hasMore = false khi hết cursor', () async {
    final adapter = RouteAdapter((o) {
      final cursor = o.queryParameters['cursor'];
      return respondJson({
        'success': true,
        'data': cursor == null ? [_tx('a', 'Debit')] : [_tx('b', 'Debit')],
        'meta': {'cursor': cursor == null ? 'c1' : null},
      });
    });
    final c = build(adapter);
    await pumpEventQueue();
    expect(c.hasMore, isTrue);

    await c.loadMore();

    expect(c.state.value!.map((t) => t.id), ['a', 'b']);
    expect(adapter.requests.last.queryParameters['cursor'], 'c1');
    expect(c.hasMore, isFalse);

    final before = adapter.requests.length;
    await c.loadMore();
    expect(adapter.requests.length, before);
  });

  test('tải danh sách sẽ đồng bộ hàng đợi offline TRƯỚC khi gọi GET', () async {
    await db.enqueueSync(SyncQueueCompanion.insert(
      clientRequestId: 'req-1',
      endpoint: '/api/v1/transactions',
      payload: '{"amountCents":1}',
      createdAt: DateTime.now(),
    ));
    final adapter = RouteAdapter((o) => o.method == 'POST'
        ? respondJson({'success': true, 'data': _tx('s1', 'Debit')})
        : respondJson({'success': true, 'data': [_tx('s1', 'Debit')], 'meta': {'cursor': null}}));

    build(adapter);
    await pumpEventQueue();

    expect(adapter.requests.map((r) => r.method), ['POST', 'GET']);
    expect(await db.pendingSyncCount(), 0);
  });

  test('lỗi đồng bộ hàng đợi không chặn việc tải danh sách', () async {
    await db.enqueueSync(SyncQueueCompanion.insert(
      clientRequestId: 'req-1',
      endpoint: '/api/v1/transactions',
      payload: 'không-phải-json',
      createdAt: DateTime.now(),
    ));
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': [_tx('a', 'Debit')], 'meta': {'cursor': null}}));

    final c = build(adapter);
    await pumpEventQueue();

    expect(c.state.value, hasLength(1));
  });

  test('chưa đăng nhập: danh sách rỗng và không gọi API', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': []}));

    final c = build(adapter, enabled: false);
    await pumpEventQueue();

    expect(c.state.value, isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('createTransaction thêm lên đầu danh sách khi khớp bộ lọc, bỏ qua khi không khớp', () async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') return respondJson({'success': true, 'data': _tx('new', 'Debit')});
      return respondJson({'success': true, 'data': [_tx('old', 'Credit')], 'meta': {'cursor': null}});
    });
    final c = build(adapter);
    await pumpEventQueue();

    await c.createTransaction(accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.now());
    expect(c.state.value!.map((t) => t.id), ['new', 'old']);

    await c.setFilter(TransactionType.income);
    await c.createTransaction(accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.now());
    expect(c.state.value!.map((t) => t.id), ['old']);
  });

  test('lưu lại cùng một giao dịch (server trả 200 bản cũ) không hiện hai dòng', () async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') return respondJson({'success': true, 'data': _tx('same', 'Debit')});
      return respondJson({'success': true, 'data': [_tx('old', 'Debit')], 'meta': {'cursor': null}});
    });
    final c = build(adapter);
    await pumpEventQueue();

    for (var i = 0; i < 2; i++) {
      await c.createTransaction(
          accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.now(), clientRequestId: 'r1');
    }

    expect(c.state.value!.map((t) => t.id), ['same', 'old']);
  });

  test('onDataChanged được gọi sau khi tạo/chuyển thành công để làm mới số dư và báo cáo', () async {
    var changed = 0;
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST' || o.method == 'PATCH') return respondJson({'success': true, 'data': _tx('new', 'Debit')});
      return respondJson({'success': true, 'data': <dynamic>[], 'meta': {'cursor': null}});
    });
    final c = build(adapter, onDataChanged: () => changed++);
    await pumpEventQueue();
    expect(changed, 0);

    await c.createTransaction(accountId: 'a', amountCents: BigInt.from(1), type: TransactionType.expense, date: DateTime.now());
    expect(changed, 1);
    await c.transferInternal(amountCents: BigInt.from(1), fromAccountId: 'a', toAccountId: 'b', date: DateTime.now());
    expect(changed, 2);
  });

  test('onDataChanged không được gọi khi server từ chối giao dịch', () async {
    var changed = 0;
    final adapter = RouteAdapter((o) => o.method == 'POST'
        ? respondJson({'success': false, 'data': null, 'error': {'code': 'X', 'message': 'Lỗi'}}, status: 400)
        : respondJson({'success': true, 'data': <dynamic>[], 'meta': {'cursor': null}}));
    final c = build(adapter, onDataChanged: () => changed++);
    await pumpEventQueue();

    await expectLater(c.createTransaction(accountId: 'a', amountCents: BigInt.from(1), type: TransactionType.expense, date: DateTime.now()), throwsA(anything));

    expect(changed, 0);
  });

  test('đồng bộ được giao dịch offline khi mở lại thì làm mới số dư (onDataChanged)', () async {
    var changed = 0;
    await db.enqueueSync(SyncQueueCompanion.insert(
      clientRequestId: 'req-1',
      endpoint: '/api/v1/transactions',
      payload: '{"amountCents":1}',
      createdAt: DateTime.now(),
    ));
    final adapter = RouteAdapter((o) => o.method == 'POST'
        ? respondJson({'success': true, 'data': _tx('s1', 'Debit')})
        : respondJson({'success': true, 'data': <dynamic>[], 'meta': {'cursor': null}}));

    build(adapter, onDataChanged: () => changed++);
    await pumpEventQueue();

    expect(changed, 1);
  });

  test('đổi người dùng thì controller được tạo lại và tải lại', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': [_tx('a', 'Debit')], 'meta': {'cursor': null}}));
    final api = testApiClient(adapter);
    final userId = StateProvider<String?>((ref) => 'u1');
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
      transactionRepositoryProvider.overrideWithValue(TransactionRepository(apiClient: api, database: db)),
      syncServiceProvider.overrideWithValue(SyncService(db: db, apiClient: api)),
    ]);
    addTearDown(container.dispose);
    container.listen(transactionControllerProvider, (_, __) {});
    await pumpEventQueue();
    expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(1));

    container.read(userId.notifier).state = 'u2';
    await pumpEventQueue();

    expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
  });
}
