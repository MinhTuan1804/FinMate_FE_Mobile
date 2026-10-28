import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/transactions/data/local_transaction_mapper.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../../fixtures/fixture.dart';

TransactionEntity _localTx({String id = 'local-1', String clientRequestId = 'req-1', bool synced = false}) => TransactionEntity(
      id: id,
      amountCents: BigInt.from(45000),
      type: TransactionType.expense,
      description: 'Cơm trưa',
      date: DateTime.utc(2026, 9, 30, 5),
      accountId: 'acc-1',
      isSynced: synced,
      clientRequestId: clientRequestId,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('TransactionEntity.fromJson đọc transactions.json thật (Debit/Credit/Transfer, categoryName, meta.cursor)', () {
    final list = (fixtureData('transactions') as List).map((e) => TransactionEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list.map((t) => t.type), [TransactionType.transfer, TransactionType.income, TransactionType.expense]);
    expect(list[0].isInternalTransfer, isTrue);
    expect(list[0].toAccountId, isNotNull);
    expect(list[2].categoryName, 'Ăn uống');
    expect(list[2].categoryId, isNotNull);
    expect(list[2].amountCents, BigInt.from(45000));
    expect(list[2].status, TransactionStatus.confirmed);
    expect(list[2].isSynced, isTrue);
    expect(fixture('transactions')['meta']['cursor'], isNull);
  });

  test('TransactionType map hai chiều với API (kể cả tên cũ expense/income)', () {
    expect(TransactionType.expense.apiValue, 'Debit');
    expect(TransactionType.income.apiValue, 'Credit');
    expect(TransactionType.fromApi('Credit'), TransactionType.income);
    expect(TransactionType.fromApi('debit'), TransactionType.expense);
    expect(TransactionType.fromApi('income'), TransactionType.income);
    expect(TransactionType.fromApi('Transfer'), TransactionType.transfer);
  });

  test('toRequestJson đúng hợp đồng: số nguyên, UTC, Debit, source Manual; bỏ trường rỗng', () {
    final json = _localTx().copyWith(categoryId: 'cat-1').toRequestJson();

    expect(json['financialAccountId'], 'acc-1');
    expect(json['categoryId'], 'cat-1');
    expect(json['amountCents'], 45000);
    expect(json['transactionType'], 'Debit');
    expect(json['transactedAt'], '2026-09-30T05:00:00.000Z');
    expect(json['clientRequestId'], 'req-1');
    expect(json['source'], 'Manual');
    expect(json.containsKey('merchantName'), isFalse);
    expect(_localTx().toRequestJson().containsKey('categoryId'), isFalse);
  });

  test('toRequestJson của chuyển tiền dùng from/toAccountId và không có category', () {
    final transfer = TransactionEntity.internalTransfer(
      id: 't',
      amountCents: BigInt.from(1000000),
      fromAccountId: 'bank',
      toAccountId: 'cash',
      description: 'Rút tiền',
      date: DateTime.utc(2026, 9, 30),
      clientRequestId: 'req-t',
    );

    expect(transfer.toRequestJson(), {
      'fromAccountId': 'bank',
      'toAccountId': 'cash',
      'amountCents': 1000000,
      'transactedAt': '2026-09-30T00:00:00.000Z',
      'description': 'Rút tiền',
      'clientRequestId': 'req-t',
    });
  });

  group('getTransactions', () {
    test('gửi bộ lọc lên server và trả trang kèm cursor', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': true,
            'data': fixtureData('transactions'),
            'meta': {'cursor': 'next-1'},
          }));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

      final page = await repo.getTransactions(type: TransactionType.expense, cursor: 'c0', limit: 10);

      final q = adapter.requests.single.queryParameters;
      expect(q['type'], 'Debit');
      expect(q['cursor'], 'c0');
      expect(q['limit'], 10);
      expect(page.items, hasLength(3));
      expect(page.nextCursor, 'next-1');
    });

    test('401 được ném lại, KHÔNG âm thầm trả dữ liệu cache', () async {
      await db.insertLocalTransaction(toCompanion(_localTx(synced: true)));
      final adapter = RouteAdapter((o) => respondJson({'success': false, 'data': null, 'error': {'code': 'X', 'message': 'Hết phiên'}}, status: 401));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

      await expectLater(repo.getTransactions(), throwsA(isA<ApiException>()));
    });

    test('lỗi 500 cũng được ném lại', () async {
      final adapter = RouteAdapter((o) => respondJson({'oops': true}, status: 500));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

      await expectLater(repo.getTransactions(), throwsA(isA<ApiException>()));
    });

    test('mất mạng: trả dữ liệu cache local (không có cursor)', () async {
      await db.insertLocalTransaction(toCompanion(_localTx()));
      final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);

      final page = await repo.getTransactions();

      expect(page.items.single.description, 'Cơm trưa');
      expect(page.items.single.isSynced, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('mất mạng: bộ lọc loại giao dịch áp dụng lên cache', () async {
      await db.insertLocalTransaction(toCompanion(_localTx()));
      final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);

      final page = await repo.getTransactions(type: TransactionType.income);

      expect(page.items, isEmpty);
    });
  });

  group('createTransaction', () {
    Future<TransactionEntity> create(TransactionRepository repo) => repo.createTransaction(
          accountId: 'acc-1',
          categoryId: 'cat-1',
          amountCents: BigInt.from(45000),
          type: TransactionType.expense,
          description: 'Cơm trưa',
          date: DateTime.utc(2026, 9, 30, 5),
        );

    test('thành công: dòng local được thay bằng dòng server, không xếp hàng', () async {
      final server = (fixtureData('transactions') as List)[2];
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': server}));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

      final tx = await create(repo);

      final sent = adapter.requests.single.data as Map;
      expect(sent['transactionType'], 'Debit');
      expect(sent['clientRequestId'], isNotEmpty);
      expect(tx.id, server['id']);
      expect(tx.isSynced, isTrue);
      final rows = await db.getAllTransactions();
      expect(rows.single.id, server['id']);
      expect(rows.single.syncStatus, 'synced');
      expect(await db.pendingSyncCount(), 0);
    });

    test('mất mạng: xếp hàng đồng bộ với payload đúng hợp đồng, entity chưa đồng bộ', () async {
      final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);

      final tx = await create(repo);

      expect(tx.isSynced, isFalse);
      final queue = await db.getPendingSyncItems();
      expect(queue, hasLength(1));
      expect(queue.single.endpoint, '/api/v1/transactions');
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['financialAccountId'], 'acc-1');
      expect(payload['clientRequestId'], queue.single.clientRequestId);
      expect((await db.getAllTransactions()).single.syncStatus, 'pending');
    });

    test('server từ chối (400): xóa dòng local, không xếp hàng, ném lỗi lại', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': false,
            'data': null,
            'error': {'code': 'FINANCIAL_ACCOUNT_NOT_FOUND', 'message': 'Không tìm thấy tài khoản.'},
          }, status: 400));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

      await expectLater(create(repo), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FINANCIAL_ACCOUNT_NOT_FOUND')));

      expect(await db.getAllTransactions(), isEmpty);
      expect(await db.pendingSyncCount(), 0);
    });

    test('source được gửi lên server (Voice) và mặc định là Manual', () async {
      final server = (fixtureData('transactions') as List)[2];
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': server}));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);

      await repo.createTransaction(accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.utc(2026, 9, 30), source: 'Voice');
      await repo.createTransaction(accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.utc(2026, 9, 30));

      expect((adapter.requests[0].data as Map)['source'], 'Voice');
      expect((adapter.requests[1].data as Map)['source'], 'Manual');
    });

    test('nhóm hóa đơn: mỗi lần gọi một clientRequestId mới, thử lại dùng lại id được truyền; receiptGroup vào body và hàng đợi', () async {
      final server = (fixtureData('transactions') as List)[2];
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': server}));
      final repo = TransactionRepository(apiClient: testApiClient(adapter), database: db);
      Future<void> send({String? id}) => repo.createTransaction(
          accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.utc(2026, 9, 30), source: 'Receipt', receiptScanId: 's1', receiptGroup: 'food', clientRequestId: id);

      await send();
      await send();
      await send(id: 'retry-1');

      final bodies = adapter.requests.map((r) => r.data as Map).toList();
      expect(bodies[0]['clientRequestId'], isNot(bodies[1]['clientRequestId']));
      expect(bodies[2]['clientRequestId'], 'retry-1');
      expect(bodies.map((b) => b['receiptGroup']), ['food', 'food', 'food']);

      final offline = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);
      await offline.createTransaction(accountId: 'acc-1', amountCents: BigInt.from(1000), type: TransactionType.expense, date: DateTime.utc(2026, 9, 30), receiptGroup: 'unknown');
      expect(jsonDecode((await db.getPendingSyncItems()).single.payload)['receiptGroup'], 'unknown');
    });

    test('chuyển tiền mất mạng xếp hàng vào endpoint transfer', () async {
      final repo = TransactionRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))), database: db);

      await repo.transferInternal(
        amountCents: BigInt.from(1000000),
        fromAccountId: 'bank',
        toAccountId: 'cash',
        date: DateTime.utc(2026, 9, 30),
      );

      expect((await db.getPendingSyncItems()).single.endpoint, '/api/v1/transactions/transfer');
    });
  });
}
