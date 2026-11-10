import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/support/data/support_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('SupportRepository', () {
    test('createTicket() POST đúng path + body, parse detail trả về', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_ticket_detail', status: 201));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final detail = await repo.createTicket(category: 'Transaction', subject: 'Giao dịch bị trùng', body: 'Nội dung');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/support/tickets'));
      expect(req.data, {'category': 'Transaction', 'subject': 'Giao dịch bị trùng', 'body': 'Nội dung'});
      expect(detail.ticket.category, 'Transaction');
      expect(detail.ticket.status, 'New');
      expect(detail.messages, hasLength(1));
      expect(detail.messages.first.kind, 'Customer');
    });

    test('createTicket() với lỗi quá nhiều ca chưa đóng → ném đúng ApiException', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_error_too_many_open', status: 422));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.createTicket(category: 'Question', subject: 'A', body: 'B'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SUPPORT_TOO_MANY_OPEN_TICKETS')),
      );
    });

    test('listTickets() GET đúng path, parse danh sách', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_tickets_list'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final tickets = await repo.listTickets();

      expect(adapter.requests.single.path, contains('/api/v1/support/tickets'));
      expect(tickets, hasLength(2));
      expect(tickets.first.category, 'Transaction');
      expect(tickets.last.rating, 4);
    });

    test('getTicket() GET đúng path theo id', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_ticket_detail'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final detail = await repo.getTicket('aaaaaaaa-0000-0000-0000-000000000001');

      expect(adapter.requests.single.path, contains('/api/v1/support/tickets/aaaaaaaa-0000-0000-0000-000000000001'));
      expect(detail.ticket.id, 'aaaaaaaa-0000-0000-0000-000000000001');
    });

    test('reply() POST đúng path /messages + body {body}', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_ticket_detail_with_reply'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final detail = await repo.reply('aaaaaaaa-0000-0000-0000-000000000001', 'Đây là ảnh chụp màn hình.');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/support/tickets/aaaaaaaa-0000-0000-0000-000000000001/messages'));
      expect(req.data, {'body': 'Đây là ảnh chụp màn hình.'});
      expect(detail.messages, hasLength(2));
    });

    test('addAttachment() upload multipart field "file" đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_attachment'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final tmpFile = await _writeTempJpeg();
      final attachment = await repo.addAttachment(
        ticketId: 'aaaaaaaa-0000-0000-0000-000000000001',
        messageId: 'bbbbbbbb-0000-0000-0000-000000000001',
        filePath: tmpFile.path,
        fileName: 'anh.jpg',
      );

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/messages/bbbbbbbb-0000-0000-0000-000000000001/attachments'));
      expect(req.data, isA<FormData>());
      expect((req.data as FormData).files.single.key, 'file');
      expect(attachment.contentType, 'image/jpeg');
      await _deleteTempFile(tmpFile);
    });

    test('addAttachment() với lỗi định dạng ảnh không hợp lệ → ném đúng ApiException', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_error_attachment_invalid', status: 422));
      final repo = SupportRepository(apiClient: testApiClient(adapter));
      final tmpFile = await _writeTempJpeg();

      await expectLater(
        repo.addAttachment(
          ticketId: 'aaaaaaaa-0000-0000-0000-000000000001',
          messageId: 'bbbbbbbb-0000-0000-0000-000000000001',
          filePath: tmpFile.path,
          fileName: 'anh.jpg',
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SUPPORT_ATTACHMENT_INVALID')),
      );
      await _deleteTempFile(tmpFile);
    });

    test('getAttachmentBytes() đọc bytes thô + content-type từ header (không qua envelope JSON)', () async {
      final bytes = [0xFF, 0xD8, 0xFF, 0x01, 0x02];
      final adapter = RouteAdapter((o) => ResponseBody.fromBytes(
            bytes,
            200,
            headers: {'content-type': ['image/jpeg']},
          ));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final content = await repo.getAttachmentBytes('aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001');

      expect(adapter.requests.single.path, contains('/attachments/cccccccc-0000-0000-0000-000000000001'));
      expect(content.data, bytes);
      expect(content.contentType, 'image/jpeg');
    });

    test('getAttachmentBytes() với lỗi: tự giải mã JSON lỗi từ bytes thô (không qua ApiClient._handleError)', () async {
      final errorJson = jsonEncode({
        'success': false,
        'data': null,
        'error': {'code': 'SUPPORT_INVALID_LINK', 'message': 'Đường dẫn không hợp lệ.'},
        'meta': null,
      });
      final adapter = RouteAdapter((o) => ResponseBody.fromBytes(utf8.encode(errorJson), 404));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.getAttachmentBytes('aaaaaaaa-0000-0000-0000-000000000001', 'khong-ton-tai'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SUPPORT_INVALID_LINK')),
      );
    });

    test('close() POST đúng path /close', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_ticket_closed'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final ticket = await repo.close('aaaaaaaa-0000-0000-0000-000000000001');

      expect(adapter.requests.single.path, contains('/close'));
      expect(ticket.status, 'Closed');
      expect(ticket.isClosed, isTrue);
    });

    test('rate() POST đúng path /rating + body {rating}', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_ticket_rated'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final ticket = await repo.rate('aaaaaaaa-0000-0000-0000-000000000001', 5);

      final req = adapter.requests.single;
      expect(req.path, contains('/rating'));
      expect(req.data, {'rating': 5});
      expect(ticket.rating, 5);
    });

    test('listAccessRequests() GET đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_access_requests'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final requests = await repo.listAccessRequests('aaaaaaaa-0000-0000-0000-000000000001');

      expect(adapter.requests.single.path, contains('/access-requests'));
      expect(requests, hasLength(1));
      expect(requests.first.scopes, ['Accounts', 'Transactions']);
      expect(requests.first.isPending, isTrue);
      expect(requests.first.requiresDraftAccount, isFalse);
    });

    test('approveAccess() POST đúng path /approve, có gửi financialAccountId khi có', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_access_request_approved'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final result = await repo.approveAccess(
        ticketId: 'aaaaaaaa-0000-0000-0000-000000000001',
        requestId: 'dddddddd-0000-0000-0000-000000000001',
        financialAccountId: 'eeeeeeee-0000-0000-0000-000000000001',
      );

      final req = adapter.requests.single;
      expect(req.path, contains('/access-requests/dddddddd-0000-0000-0000-000000000001/approve'));
      expect(req.data, {'financialAccountId': 'eeeeeeee-0000-0000-0000-000000000001'});
      expect(result.isApproved, isTrue);
    });

    test('approveAccess() không có financialAccountId thì body rỗng', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_access_request_approved'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      await repo.approveAccess(ticketId: 'aaaaaaaa-0000-0000-0000-000000000001', requestId: 'dddddddd-0000-0000-0000-000000000001');

      expect(adapter.requests.single.data, <String, dynamic>{});
    });

    test('denyAccess() POST đúng path /deny', () async {
      // BE trả về 1 object SupportAccessRequestDto (đã deny), không phải danh sách.
      final adapter = RouteAdapter((o) => respondFixture('support_access_request_approved'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      await repo.denyAccess(ticketId: 'aaaaaaaa-0000-0000-0000-000000000001', requestId: 'dddddddd-0000-0000-0000-000000000001');

      expect(adapter.requests.single.path, contains('/deny'));
    });

    test('revokeAccess() POST đúng path /revoke', () async {
      // BE trả về 1 object SupportAccessRequestDto (đã revoke), không phải danh sách.
      final adapter = RouteAdapter((o) => respondFixture('support_access_request_approved'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      await repo.revokeAccess(ticketId: 'aaaaaaaa-0000-0000-0000-000000000001', requestId: 'dddddddd-0000-0000-0000-000000000001');

      expect(adapter.requests.single.path, contains('/revoke'));
    });

    test('accessLog() GET đúng path, parse danh sách', () async {
      final adapter = RouteAdapter((o) => respondFixture('support_access_log'));
      final repo = SupportRepository(apiClient: testApiClient(adapter));

      final log = await repo.accessLog();

      expect(adapter.requests.single.path, contains('/api/v1/support/access-log'));
      expect(log, hasLength(2));
      expect(log.first.scope, 'Transactions');
    });
  });
}

Future<dynamic> _writeTempJpeg() async {
  // ignore: avoid_slow_async_io
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/support_test_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  return file;
}

// Trên Windows, dio chỉ nhả file-handle (sau khi đọc để build multipart) một nhịp sau khi request
// hoàn tất — xoá ngay có thể đụng PathAccessException dù file không còn dùng nữa. Dọn best-effort.
Future<void> _deleteTempFile(File file) async {
  try {
    await file.delete();
  } catch (_) {}
}
