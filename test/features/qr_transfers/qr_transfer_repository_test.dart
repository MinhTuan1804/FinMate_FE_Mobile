import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/qr_transfers/data/qr_transfer_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('QrTransferRepository', () {
    test('getBanks() gọi GET /api/v1/qr/banks, đọc đúng canMatchNotifications', () async {
      final adapter = RouteAdapter((o) => respondFixture('qr_banks'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final banks = await repo.getBanks();

      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, contains('/api/v1/qr/banks'));
      expect(banks, hasLength(3));
      final mb = banks.firstWhere((b) => b.bin == '970422');
      expect(mb.name, isNotEmpty);
      expect(mb.canMatchNotifications, isTrue);
      final vcb = banks.firstWhere((b) => b.bin == '970436');
      expect(vcb.canMatchNotifications, isFalse);
    });

    test('createTransfer gửi đúng body (kể cả null khi không có receiverName/message/categoryId)', () async {
      final adapter = RouteAdapter((o) => respondFixture('qr_transfer_created'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final result = await repo.createTransfer(
        receiverBankBin: '970422',
        receiverAccountNumber: 'ACC123',
        senderBankBin: '970415',
        amountCents: BigInt.from(500000),
      );

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/qr/transfers'));
      expect(req.data, {
        'receiverBankBin': '970422',
        'receiverAccountNumber': 'ACC123',
        'receiverName': null,
        'senderBankBin': '970415',
        'amountCents': 500000,
        'message': null,
        'categoryId': null,
      });
      expect(result.isPending, isTrue);
    });

    test('createTransfer gửi đầy đủ receiverName/message/categoryId khi có', () async {
      final adapter = RouteAdapter((o) => respondFixture('qr_transfer_created'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      await repo.createTransfer(
        receiverBankBin: '970422',
        receiverAccountNumber: 'ACC123',
        receiverName: 'Nguyễn Văn A',
        senderBankBin: '970415',
        amountCents: BigInt.from(500000),
        message: 'Chuyển tiền ăn uống',
        categoryId: '412878cb-aced-4b3f-a2c9-637838245e6f',
      );

      final req = adapter.requests.single;
      expect(req.data['receiverName'], 'Nguyễn Văn A');
      expect(req.data['message'], 'Chuyển tiền ăn uống');
      expect(req.data['categoryId'], '412878cb-aced-4b3f-a2c9-637838245e6f');
    });

    test('listTransfers() mặc định limit=50, không gửi status', () async {
      final adapter = RouteAdapter((o) => respondFixture('qr_transfers_list'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final list = await repo.listTransfers();

      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, contains('/api/v1/qr/transfers'));
      expect(req.queryParameters['status'], isNull);
      expect(req.queryParameters['limit'], 50);
      expect(list, hasLength(3));
      expect(list.firstWhere((t) => t.id == 'qr-2').isMatched, isTrue);
      expect(list.firstWhere((t) => t.id == 'qr-3').isExpired, isTrue);
    });

    test('listTransfers(status: ...) gửi đúng query status', () async {
      final adapter = RouteAdapter((o) => respondFixture('qr_transfers_list'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      await repo.listTransfers(status: 'Pending');

      expect(adapter.requests.single.queryParameters['status'], 'Pending');
    });

    test('cancelTransfer POST đúng path, trả về trạng thái Cancelled', () async {
      final adapter = RouteAdapter((o) => respondFixture('qr_transfer_cancelled'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final result = await repo.cancelTransfer('qr-1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/qr/transfers/qr-1/cancel'));
      expect(result.isCancelled, isTrue);
    });

    test('lookupCounterparty: có mapping trả về đối tượng, gửi đúng body', () async {
      final adapter = RouteAdapter((o) => respondFixture('counterparty_override'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final result = await repo.lookupCounterparty(bankBin: '970422', accountNumber: 'ACC123');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/qr/counterparties/lookup'));
      expect(req.data, {'bankBin': '970422', 'accountNumber': 'ACC123'});
      expect(result, isNotNull);
      expect(result!.categoryName, isNotEmpty);
    });

    test('lookupCounterparty: chưa có mapping trả về null (không lỗi)', () async {
      final adapter = RouteAdapter((o) => respondFixture('counterparty_override_null'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final result = await repo.lookupCounterparty(bankBin: '970422', accountNumber: 'ACCXYZ');

      expect(result, isNull);
    });

    test('listCounterparties() đọc đúng danh sách', () async {
      final adapter = RouteAdapter((o) => respondFixture('counterparty_overrides_list'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final list = await repo.listCounterparties();

      expect(adapter.requests.single.method, 'GET');
      expect(list, hasLength(2));
    });

    test('updateCounterparty PATCH đúng path và body', () async {
      final adapter = RouteAdapter((o) => respondFixture('counterparty_override_updated'));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      final result = await repo.updateCounterparty('ov-2', '412878cb-aced-4b3f-a2c9-637838245e6f');

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, contains('/api/v1/qr/counterparties/ov-2'));
      expect(req.data, {'categoryId': '412878cb-aced-4b3f-a2c9-637838245e6f'});
      expect(result.categoryName, isNotEmpty);
    });

    test('deleteCounterparty gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = QrTransferRepository(apiClient: testApiClient(adapter));

      await repo.deleteCounterparty('ov-1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, contains('/api/v1/qr/counterparties/ov-1'));
    });
  });
}
