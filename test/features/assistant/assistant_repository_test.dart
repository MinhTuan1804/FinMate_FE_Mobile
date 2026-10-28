import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('chat', () {
    test('gửi đúng đường dẫn và body (bỏ khóa null) và đọc action saved', () async {
      final adapter = RouteAdapter((o) => respondFixture('chat_saved'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      final reply = await repo.chat('cafe highlands 55k', accountId: 'acc-1', clientRequestId: 'req-1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/transactions/chat');
      expect(req.data, {'text': 'cafe highlands 55k', 'financialAccountId': 'acc-1', 'clientRequestId': 'req-1'});
      expect(reply.action, ChatAction.saved);
      expect(reply.transaction!.amountCents, BigInt.from(55000));
    });

    test('không có accountId/clientRequestId thì body chỉ có text', () async {
      final adapter = RouteAdapter((o) => respondFixture('chat_summary'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      final reply = await repo.chat('tháng này tôi tiêu bao nhiêu');

      expect(adapter.requests.single.data, {'text': 'tháng này tôi tiêu bao nhiêu'});
      expect(reply.action, ChatAction.summary);
    });

    test('đọc được action confirm với bản nháp', () async {
      final repo = AssistantRepository(apiClient: testApiClient(RouteAdapter((o) => respondFixture('chat_confirm_expense'))));

      final reply = await repo.chat('lương 20 triệu');

      expect(reply.action, ChatAction.confirm);
      expect(reply.draft!.missingFields, ['category']);
    });

    test('AI service không sẵn sàng: ném ApiException với đúng code', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': false,
            'data': null,
            'error': {'code': 'NOTIFICATION_AI_SERVICE_UNAVAILABLE', 'message': 'AI Service không phản hồi hoặc trả lỗi.'},
          }, status: 503));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.chat('x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NOTIFICATION_AI_SERVICE_UNAVAILABLE')),
      );
    });

    test('mất mạng: ném NetworkException', () async {
      final repo = AssistantRepository(apiClient: testApiClient(RouteAdapter((o) => throwNetworkDown(o))));

      await expectLater(repo.chat('x'), throwsA(isA<NetworkException>()));
    });
  });

  group('parse', () {
    test('gọi /transactions/parse và trả bản nháp với nguồn được chỉ định', () async {
      final adapter = RouteAdapter((o) => respondFixture('parse_ok'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      final draft = await repo.parse('an trua com tam 45k bang vi tien mat', source: DraftSource.voice);

      expect(adapter.requests.single.path, '/api/v1/transactions/parse');
      expect(adapter.requests.single.data, {'text': 'an trua com tam 45k bang vi tien mat'});
      expect(draft.amountCents, BigInt.from(45000));
      expect(draft.source, DraftSource.voice);
    });
  });

  group('scanReceipt', () {
    test('gửi multipart với field "file" và đọc kết quả OCR', () async {
      final adapter = RouteAdapter((o) => respondFixture('scan_receipt_success'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      final scan = await repo.scanReceipt('test/fixtures/receipt_sample.png');

      final req = adapter.requests.single;
      expect(req.path, '/api/v1/transactions/scan-receipt');
      expect(req.data, isA<FormData>());
      expect((req.data as FormData).files.single.key, 'file');
      expect(scan.success, isTrue);
      expect(scan.draft.merchantName, 'WinMart');
    });

    test('file không tồn tại: ném lỗi (không gọi mạng)', () async {
      final adapter = RouteAdapter((o) => respondFixture('scan_receipt_success'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      await expectLater(repo.scanReceipt('test/fixtures/khong_ton_tai.png'), throwsA(anything));
      expect(adapter.requests, isEmpty);
    });
  });

  group('voiceChat', () {
    test('gửi multipart "file" kèm ví và mã yêu cầu, đọc câu nghe được + kết quả chat (phản hồi thật của BE)', () async {
      final adapter = RouteAdapter((o) => respondFixture('voice_chat_multi'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      final reply = await repo.voiceChat('test/fixtures/receipt_sample.png', accountId: 'acc-1', clientRequestId: 'req-1');

      final req = adapter.requests.single;
      expect(req.path, '/api/v1/transactions/voice');
      final form = req.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.fields.map((f) => (f.key, f.value)), containsAll([('financialAccountId', 'acc-1'), ('clientRequestId', 'req-1')]));
      expect(reply.transcript, 'hôm qua ăn phở bốn mươi nghìn rồi đổ xăng bảy mươi nghìn');
      expect(reply.chat.action, ChatAction.confirm);
      expect(reply.chat.drafts.map((d) => d.amountCents), [BigInt.from(40000), BigInt.from(70000)]);
    });

    test('không nghe được gì: ném ApiException với đúng code', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': false,
            'data': null,
            'error': {'code': 'TRANSACTION_VOICE_NO_SPEECH', 'message': 'Không nghe rõ nội dung. Hãy ghi âm lại hoặc gõ tay.'},
          }, status: 422));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.voiceChat('test/fixtures/receipt_sample.png'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TRANSACTION_VOICE_NO_SPEECH')),
      );
    });
  });

  group('analyze', () {
    test('gửi đúng đường dẫn và đọc phản hồi thật của backend (chỉ hiểu câu, không ghi gì)', () async {
      final adapter = RouteAdapter((o) => respondFixture('chat_analyze_multi'));
      final repo = AssistantRepository(apiClient: testApiClient(adapter));

      final analysis = await repo.analyze('ăn phở 40k và đổ xăng 70k tổng cộng 100k');

      expect(adapter.requests.single.path, '/api/v1/chat/analyze');
      expect(adapter.requests.single.data, {'text': 'ăn phở 40k và đổ xăng 70k tổng cộng 100k'});
      expect(analysis.entries.map((e) => e.categorySlug), ['food', 'transport']);
      expect(analysis.totalMismatch, isTrue);
    });
  });
}
