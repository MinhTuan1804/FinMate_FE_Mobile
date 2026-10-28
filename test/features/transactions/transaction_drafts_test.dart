import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/features/transactions/data/local_transaction_mapper.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _tx(String id, {String status = 'Confirmed', String type = 'Debit'}) => {
      'id': id,
      'financialAccountId': 'acc-1',
      'counterAccountId': null,
      'categoryId': 'cat-1',
      'categoryName': 'Ăn uống',
      'amountCents': 1000,
      'transactionType': type,
      'source': 'Notification',
      'status': status,
      'merchantName': null,
      'description': id,
      'transactedAt': '2026-09-30T05:00:00+00:00',
      'balanceAfterCents': 0,
      'createdAt': '2026-09-30T05:00:00+00:00',
    };

ResponseBody _list(List<Map<String, dynamic>> data) => respondJson({'success': true, 'data': data, 'meta': {'cursor': null}});

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  TransactionRepository repoFor(RouteAdapter adapter) => TransactionRepository(apiClient: testApiClient(adapter), database: db);

  group('repository', () {
    test('default_list_requests_status_Confirmed', () async {
      final adapter = RouteAdapter((o) => _list([_tx('a')]));

      await repoFor(adapter).getTransactions();

      expect(adapter.requests.single.queryParameters['status'], 'Confirmed');
    });

    test('drafts_request_status_Draft_and_are_not_cached', () async {
      final adapter = RouteAdapter((o) => _list([_tx('d1', status: 'Draft')]));

      final page = await repoFor(adapter).getTransactions(status: TransactionStatus.draft);

      expect(adapter.requests.single.queryParameters['status'], 'Draft');
      expect(page.items.single.status, TransactionStatus.draft);
      expect(await db.getAllTransactions(), isEmpty);
    });

    test('offline_history_does_not_return_a_previously_fetched_draft', () async {
      var offline = false;
      final adapter = RouteAdapter((o) => offline ? throwNetworkDown(o) : _list([_tx('d1', status: 'Draft')]));
      final repo = repoFor(adapter);
      await repo.getTransactions(status: TransactionStatus.draft);
      // Một dòng nháp lọt vào cache (ví dụ từ bản cũ) cũng không được hiện ở lịch sử offline.
      await db.insertLocalTransaction(toCompanion(TransactionEntity.fromJson(_tx('d2', status: 'Draft'))));
      await db.insertLocalTransaction(toCompanion(TransactionEntity.fromJson(_tx('c1'))));
      offline = true;

      final page = await repo.getTransactions();

      expect(page.items.map((t) => t.id), ['c1']);
      expect((await repo.getTransactions(status: TransactionStatus.draft)).items, isEmpty);
    });

    test('confirmDraft_posts_to_confirm_and_returns_entity', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': _tx('d1')}));

      final tx = await repoFor(adapter).confirmDraft('d1', categoryId: 'cat-2');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/transactions/d1/confirm');
      expect(req.data, {'categoryId': 'cat-2'});
      expect(tx.id, 'd1');
      expect(tx.status, TransactionStatus.confirmed);
    });

    test('updateDraft_patches_full_body', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': _tx('d1', status: 'Draft')}));

      final tx = await repoFor(adapter).updateDraft(
        id: 'd1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        amountCents: BigInt.from(45000),
        type: TransactionType.expense,
        date: DateTime.utc(2026, 9, 30, 5),
        merchantName: 'Highlands',
        description: 'Cà phê',
      );

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/transactions/d1');
      expect(req.data, {
        'financialAccountId': 'acc-1',
        'counterAccountId': null,
        'categoryId': 'cat-1',
        'amountCents': 45000,
        'transactionType': 'Debit',
        'transactedAt': '2026-09-30T05:00:00.000Z',
        'merchantName': 'Highlands',
        'description': 'Cà phê',
      });
      expect(tx.id, 'd1');
    });
  });

  group('controller', () {
    TransactionController build(RouteAdapter adapter, {void Function()? onDataChanged}) {
      final api = testApiClient(adapter);
      return TransactionController(
        repository: TransactionRepository(apiClient: api, database: db),
        syncService: SyncService(db: db, apiClient: api),
        onDataChanged: onDataChanged,
      );
    }

    test('setDraftsOnly_true_loads_drafts_and_ignores_type_filter', () async {
      final adapter = RouteAdapter((o) => _list(o.queryParameters['status'] == 'Draft' ? [_tx('d1', status: 'Draft')] : [_tx('a')]));
      final c = build(adapter);
      await pumpEventQueue();
      await c.setFilter(TransactionType.income);

      await c.setDraftsOnly(true);

      final q = adapter.requests.last.queryParameters;
      expect(q['status'], 'Draft');
      expect(q.containsKey('type'), isFalse);
      expect(c.draftsOnly, isTrue);
      expect(c.state.value!.map((t) => t.id), ['d1']);

      await c.setDraftsOnly(false);

      expect(adapter.requests.last.queryParameters['status'], 'Confirmed');
      expect(adapter.requests.last.queryParameters['type'], 'Credit');
      expect(c.state.value!.map((t) => t.id), ['a']);
    });

    test('confirmDraft_removes_item_and_calls_onDataChanged', () async {
      var changed = 0;
      final adapter = RouteAdapter((o) {
        if (o.method == 'POST') return respondJson({'success': true, 'data': _tx('d1')});
        return _list([_tx('d1', status: 'Draft'), _tx('d2', status: 'Draft')]);
      });
      final c = build(adapter, onDataChanged: () => changed++);
      await pumpEventQueue();
      await c.setDraftsOnly(true);

      await c.confirmDraft('d1');

      expect(c.state.value!.map((t) => t.id), ['d2']);
      expect(changed, 1);
    });

    test('saveDraft_updates_item_in_list', () async {
      final adapter = RouteAdapter((o) {
        if (o.method == 'PATCH') return respondJson({'success': true, 'data': {..._tx('d1', status: 'Draft'), 'amountCents': 99000}});
        return _list([_tx('d1', status: 'Draft')]);
      });
      final c = build(adapter);
      await pumpEventQueue();
      await c.setDraftsOnly(true);

      await c.saveDraft(
        id: 'd1',
        accountId: 'acc-1',
        amountCents: BigInt.from(99000),
        type: TransactionType.expense,
        date: DateTime.utc(2026, 9, 30),
      );

      expect(c.state.value!.single.amountCents, BigInt.from(99000));
    });

    // Danh sách theo chế độ: Confirmed trả dòng 'a' kèm cursor 'c1'; trang kế (cursor) trả 'b'; Draft trả 'd1'.
    ResponseBody byMode(RequestOptions o) {
      if (o.queryParameters['status'] == 'Draft') return _list([_tx('d1', status: 'Draft')]);
      final more = o.queryParameters['cursor'] != null;
      return respondJson({'success': true, 'data': [_tx(more ? 'b' : 'a')], 'meta': {'cursor': more ? null : 'c1'}});
    }

    test('slow_load_of_old_mode_does_not_overwrite_newer_mode', () async {
      var n = 0;
      // Request đầu (chế độ Confirmed) trả về SAU request thứ hai (chế độ Draft).
      final adapter = RouteAdapter(byMode, delayOf: (o) => n++ == 0 ? const Duration(milliseconds: 150) : Duration.zero);
      final c = build(adapter);
      await pumpEventQueue();
      expect(adapter.requests, hasLength(1));

      await c.setDraftsOnly(true);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(c.state.value!.map((t) => t.id), ['d1']);
      expect(c.hasMore, isFalse);
    });

    test('loadMore_in_flight_during_mode_switch_does_not_append_old_rows', () async {
      final adapter = RouteAdapter(byMode, delayOf: (o) => o.queryParameters['cursor'] != null ? const Duration(milliseconds: 150) : Duration.zero);
      final c = build(adapter);
      await pumpEventQueue();
      expect(c.hasMore, isTrue);

      final more = c.loadMore();
      await pumpEventQueue();
      await c.setDraftsOnly(true);
      await more;

      expect(c.state.value!.map((t) => t.id), ['d1']);
      expect(c.hasMore, isFalse);
    });

    test('create_while_in_drafts_mode_leaves_drafts_list_but_calls_onDataChanged', () async {
      var changed = 0;
      final adapter = RouteAdapter((o) {
        if (o.method == 'POST') return respondJson({'success': true, 'data': _tx('n1')});
        return byMode(o);
      });
      final c = build(adapter, onDataChanged: () => changed++);
      await pumpEventQueue();
      await c.setDraftsOnly(true);

      await c.createTransaction(
        accountId: 'acc-1',
        amountCents: BigInt.from(1000),
        type: TransactionType.expense,
        date: DateTime.utc(2026, 9, 30),
      );

      expect(c.state.value!.map((t) => t.id), ['d1']);
      expect(changed, 1);
    });
  });
}
