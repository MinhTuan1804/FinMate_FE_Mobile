import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/support/data/support_image_source.dart';
import 'package:finmate/features/support/presentation/screens/support_ticket_detail_screen.dart';
import '../../fixtures/fixture.dart';

const _ticketId = 'aaaaaaaa-0000-0000-0000-000000000001';

// MultipartFile.fromFile cần file thật trên đĩa (RouteAdapter drain stream của nó như một request thật).
// Dùng bản sync: ghi async trong testWidgets dễ bị treo vô hạn trên Windows (AutomatedTestWidgetsFlutterBinding
// không bơm được I/O thật ngoài vùng tester.runAsync, mà tester.runAsync lại không dispatch được tester.tap()).
File _writeTempJpegSync() {
  final file = File('${Directory.systemTemp.path}/support_screen_test_${DateTime.now().microsecondsSinceEpoch}.jpg');
  file.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  return file;
}

class _FakeImageSource implements SupportImageSource {
  _FakeImageSource(this.path);
  final String? path;

  @override
  Future<PickedImage?> pickFromGallery() async => path == null ? null : PickedImage(path: path!, name: 'anh.jpg');
}

RouteAdapter _adapter({
  String getTicketFixture = 'support_ticket_detail',
  String accessRequestsFixture = 'support_access_requests_empty',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/access-requests')) {
      // BE trả về 1 object SupportAccessRequestDto cho cả 3 hành động, không phải danh sách rỗng.
      if (o.method == 'POST' && o.path.contains('/approve')) return respondFixture('support_access_request_approved');
      if (o.method == 'POST' && o.path.contains('/deny')) return respondFixture('support_access_request_approved');
      if (o.method == 'POST' && o.path.contains('/revoke')) return respondFixture('support_access_request_approved');
      return respondFixture(accessRequestsFixture);
    }
    if (o.method == 'POST' && o.path.contains('/messages') && !o.path.contains('attachments')) {
      return respondFixture('support_ticket_detail_with_reply');
    }
    if (o.method == 'POST' && o.path.contains('/attachments')) {
      return respondFixture('support_attachment');
    }
    if (o.method == 'POST' && o.path.contains('/close')) {
      return respondFixture('support_ticket_closed');
    }
    if (o.method == 'POST' && o.path.contains('/rating')) {
      return respondFixture('support_ticket_rated');
    }
    return respondFixture(getTicketFixture);
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter, {String? pickedImagePath}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
      supportImageSourceProvider.overrideWithValue(_FakeImageSource(pickedImagePath)),
    ],
    child: const MaterialApp(home: SupportTicketDetailScreen(ticketId: _ticketId)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('SupportTicketDetailScreen', () {
    testWidgets('hiện tiêu đề, trạng thái và tin nhắn của khách', (tester) async {
      await _pump(tester, _adapter());
      expect(find.text('Giao dịch bị trùng'), findsOneWidget);
      expect(find.textContaining('Mới'), findsOneWidget);
      expect(find.text('Tôi thấy giao dịch 200k bị ghi 2 lần.'), findsOneWidget);
    });

    testWidgets('gửi tin nhắn gọi đúng API /messages với body đã nhập', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.enterText(find.byKey(const ValueKey('support-reply-input')), 'Đây là ảnh chụp màn hình.');
      await tester.tap(find.byKey(const ValueKey('support-reply-send')));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/messages') && !r.path.contains('attachments'));
      expect(req.data, {'body': 'Đây là ảnh chụp màn hình.'});
      expect(find.textContaining('Đã gửi tin nhắn.'), findsOneWidget);
    });

    testWidgets('gửi ảnh: trả lời trước để có messageId rồi gắn ảnh vào đúng tin nhắn đó', (tester) async {
      final adapter = _adapter();
      final tmpFile = _writeTempJpegSync();
      await _pump(tester, adapter, pickedImagePath: tmpFile.path);

      // addAttachment() đọc file thật qua MultipartFile.fromFile(), nên chuỗi await của
      // _replyWithImage phải chạy trên zone thật: gọi trực tiếp onPressed trong runAsync, bỏ qua
      // tester.tap() (không kích hoạt được onPressed khi gọi bên trong runAsync) và pumpAndSettle()
      // thường (Future I/O thật không bao giờ hoàn tất trong fake-async zone của testWidgets).
      final button = tester.widget<IconButton>(find.byKey(const ValueKey('support-reply-image')));
      await tester.runAsync(() => button.onPressed!.call() as dynamic);
      await tester.pumpAndSettle();

      final replyReq = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/messages') && !r.path.contains('attachments'));
      final attachReq = adapter.requests.firstWhere((r) => r.path.contains('/attachments'));
      // Tin nhắn vừa trả lời (fixture with_reply) có id bbbbbbbb-...002 — ảnh phải gắn đúng vào tin đó.
      expect(attachReq.path, contains('bbbbbbbb-0000-0000-0000-000000000002/attachments'));
      expect(replyReq.data, {'body': '(đã gửi ảnh)'});
      expect(find.textContaining('Đã gửi tin nhắn kèm ảnh.'), findsOneWidget);
      await tester.runAsync(() async {
        try {
          await tmpFile.delete();
        } catch (_) {}
      });
    });

    testWidgets('hủy chọn ảnh (trả về null) thì không gọi API nào', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter, pickedImagePath: null);

      await tester.tap(find.byKey(const ValueKey('support-reply-image')));
      await tester.pumpAndSettle();

      expect(adapter.requests.where((r) => r.method == 'POST').isEmpty, isTrue);
    });

    testWidgets('đóng yêu cầu gọi đúng API /close và cập nhật trạng thái', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('support-close')));
      await tester.pumpAndSettle();

      expect(adapter.requests.any((r) => r.path.contains('/close')), isTrue);
      expect(find.textContaining('Đã đóng'), findsWidgets);
    });

    testWidgets('ca đã đóng thì ẩn ô nhập tin nhắn và khóa nút đóng', (tester) async {
      await _pump(tester, _adapter(getTicketFixture: 'support_ticket_detail_closed'));

      expect(find.byKey(const ValueKey('support-reply-input')), findsNothing);
      final closeButton = tester.widget<OutlinedButton>(find.byKey(const ValueKey('support-close')));
      expect(closeButton.onPressed, isNull);
    });

    testWidgets('đánh giá 5 sao gọi đúng API /rating với rating=5', (tester) async {
      final adapter = _adapter(getTicketFixture: 'support_ticket_detail_resolved');
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('support-rate-5')));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.path.contains('/rating'));
      expect(req.data, {'rating': 5});
      expect(find.textContaining('Đã đánh giá 5/5'), findsOneWidget);
    });

    testWidgets('yêu cầu xem dữ liệu đang chờ: đồng ý gọi đúng API /approve', (tester) async {
      final adapter = _adapter(accessRequestsFixture: 'support_access_requests');
      await _pump(tester, adapter);

      expect(find.text('Danh sách ví, Giao dịch'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('support-access-approve-dddddddd-0000-0000-0000-000000000001')));
      await tester.pumpAndSettle();

      expect(adapter.requests.any((r) => r.path.contains('/approve')), isTrue);
    });

    testWidgets('yêu cầu đã đồng ý: hiện nút thu hồi, bấm gọi đúng API /revoke', (tester) async {
      final adapter = _adapter(accessRequestsFixture: 'support_access_requests_approved_list');
      await _pump(tester, adapter);

      expect(find.byKey(const ValueKey('support-access-revoke-dddddddd-0000-0000-0000-000000000001')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('support-access-revoke-dddddddd-0000-0000-0000-000000000001')));
      await tester.pumpAndSettle();

      expect(adapter.requests.any((r) => r.path.contains('/revoke')), isTrue);
    });
  });
}
