import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/draft_saver.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/data/voice_recorder.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fakes.dart';
import '../../fixtures/fixture.dart';
import '../auth/consent_fakes.dart';

const _image = 'test/fixtures/receipt_sample.png';

class _MockAccounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _MockAccounts(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository giả: trả kết quả quét theo kịch bản, đếm số lần gọi
class _ScanRepo extends AssistantRepository {
  final List<ReceiptScan Function()> script;
  final List<String> scanned = [];

  _ScanRepo(this.script) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ReceiptScan> scanReceipt(String filePath) async {
    scanned.add(filePath);
    return script[(scanned.length - 1).clamp(0, script.length - 1)]();
  }
}

class _VoiceRepo extends AssistantRepository {
  final VoiceReply Function() reply;
  final List<String> paths = [];
  final List<String?> requestIds = [];

  _VoiceRepo(this.reply) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<VoiceReply> voiceChat(String filePath, {String? accountId, String? clientRequestId}) async {
    paths.add(filePath);
    requestIds.add(clientRequestId);
    return reply();
  }
}

ReceiptScan _ok() => ReceiptScan(
      success: true,
      draft: DraftTransaction(amountCents: BigInt.from(55000), type: TransactionType.expense, source: DraftSource.receipt),
    );

ReceiptScan _unreadable() => ReceiptScan(success: false, draft: DraftTransaction(source: DraftSource.receipt));

class _Recording extends AssistantController {
  final List<(String, DraftSource)> sent = [];
  final List<String> scanned = [];
  final List<String> voiced = [];

  _Recording() : super(repository: _ScanRepo([_ok]));

  @override
  Future<void> send(String text, {DraftSource source = DraftSource.chat}) async => sent.add((text, source));

  @override
  Future<void> scanReceipt(String path) async => scanned.add(path);

  @override
  Future<void> sendVoice(String path) async => voiced.add(path);
}

void main() {
  group('AssistantController.scanReceipt', () {
    test('thành công: thêm ảnh rồi thẻ nháp nguồn hóa đơn', () async {
      final repo = _ScanRepo([_ok]);
      final c = AssistantController(repository: repo);

      await c.scanReceipt(_image);

      expect(c.state.messages.first, isA<ImageNote>());
      final draft = c.state.messages.whereType<DraftCard>().single.draft;
      expect(draft.amountCents, BigInt.from(55000));
      expect(draft.source, DraftSource.receipt);
      expect(c.state.isSending, isFalse);
    });

    test('OCR không đọc được: báo bằng tin nhắn, không có thẻ nháp', () async {
      final c = AssistantController(repository: _ScanRepo([_unreadable]));

      await c.scanReceipt(_image);

      expect(c.state.messages.whereType<DraftCard>(), isEmpty);
      expect(c.state.messages.whereType<AssistantText>().single.text, contains('Không đọc được hóa đơn'));
    });

    test('lỗi mạng: hiện lỗi và "gửi lại" quét lại đúng ảnh, không thêm ảnh thứ hai', () async {
      var calls = 0;
      final repo = _ScanRepo([
        () {
          calls++;
          throw Exception('Không có kết nối mạng.');
        },
        _ok,
      ]);
      final c = AssistantController(repository: repo);

      await c.scanReceipt(_image);
      final error = c.state.messages.whereType<ErrorNote>().single;
      await c.retry(error.id);

      expect(calls, 1);
      expect(repo.scanned, [_image, _image]);
      expect(c.state.messages.whereType<ImageNote>(), hasLength(1));
      expect(c.state.messages.whereType<ErrorNote>(), isEmpty);
      expect(c.state.messages.whereType<DraftCard>(), hasLength(1));
    });

    test('đang quét thì bỏ qua yêu cầu quét thứ hai', () async {
      final repo = _ScanRepo([_ok]);
      final c = AssistantController(repository: repo);

      final first = c.scanReceipt(_image);
      await c.scanReceipt(_image);
      await first;

      expect(repo.scanned, hasLength(1));
    });
  });

  group('AssistantController.sendVoice', () {
    VoiceReply multi() => VoiceReply.fromJson(fixtureData('voice_chat_multi') as Map<String, dynamic>);

    test('câu nghe được hiện như tin của người dùng, rồi MỘT thẻ gộp nguồn voice (nhiều khoản)', () async {
      final c = AssistantController(repository: _VoiceRepo(multi));

      await c.sendVoice('a.m4a');

      final m = c.state.messages;
      expect(m.map((e) => e.runtimeType), [UserText, AssistantText, DraftBatchCard]);
      expect((m.first as UserText).text, contains('ăn phở bốn mươi nghìn'));
      expect(m.whereType<DraftBatchCard>().single.drafts.map((d) => d.source), everyElement(DraftSource.voice));
      expect(c.state.isSending, isFalse);
    });

    test('lỗi: thẻ lỗi, thử lại dùng đúng clientRequestId cũ', () async {
      var fail = true;
      final repo = _VoiceRepo(() {
        if (fail) throw Exception('mất mạng');
        return multi();
      });
      final c = AssistantController(repository: repo);

      await c.sendVoice('a.m4a');
      final error = c.state.messages.whereType<ErrorNote>().single;
      fail = false;
      await c.retry(error.id);

      expect(repo.requestIds, hasLength(2));
      expect(repo.requestIds[0], repo.requestIds[1]);
      expect(c.state.messages.whereType<ErrorNote>(), isEmpty);
      expect(c.state.messages.whereType<DraftBatchCard>().single.drafts, hasLength(2));
    });

    test('đang gửi thì bỏ qua lần ghi âm thứ hai', () async {
      final repo = _VoiceRepo(multi);
      final c = AssistantController(repository: repo);

      final first = c.sendVoice('a.m4a');
      await c.sendVoice('b.m4a');
      await first;

      expect(repo.paths, ['a.m4a']);
    });
  });

  group('màn chat: nói và quét ngay trong chat', () {
    late _Recording assistant;
    late FakeVoiceRecorder recorder;
    late FakeImageSource images;
    late ConsentRepo consent;

    final accounts = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();

    Future<void> pumpChat(WidgetTester tester, {String? startWith}) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = AuthController(repository: consent);
      await auth.checkAuthStatus(); // hồ sơ đã nạp xong trước khi màn mở, như app thật (người dùng vào được chat là đã đăng nhập)
      await tester.pumpWidget(ProviderScope(
        overrides: [
          assistantControllerProvider.overrideWith((ref) => assistant),
          accountsControllerProvider.overrideWith((ref) => _MockAccounts(AsyncValue.data(accounts))),
          voiceRecorderProvider.overrideWithValue(recorder),
          receiptImageSourceProvider.overrideWithValue(images),
          authControllerProvider.overrideWith((ref) => auth),
        ],
        child: MaterialApp(home: AssistantScreen(startWith: startWith)),
      ));
      await tester.pumpAndSettle();
    }

    setUp(() {
      assistant = _Recording();
      recorder = FakeVoiceRecorder();
      images = FakeImageSource(cameraPath: _image, galleryPath: _image);
      consent = ConsentRepo(consentTestUser(terms: true, ai: true));
    });

    testWidgets('bấm mic: ghi âm, bấm lần nữa: dừng và gửi tệp ghi âm lên chatbot', (tester) async {
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang nghe'), findsOneWidget);
      expect(assistant.voiced, isEmpty);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();

      expect(recorder.stopCalls, 1);
      expect(assistant.voiced, [_image]);
      expect(find.textContaining('Đang nghe'), findsNothing);
    });

    testWidgets('gõ tay rồi gửi vẫn là source chat', (tester) async {
      await pumpChat(tester);

      await tester.enterText(find.byType(TextField), 'cafe 30k');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-button')));
      await tester.pump();

      expect(assistant.sent, [('cafe 30k', DraftSource.chat)]);
    });

    testWidgets('tự dừng và gửi khi người dùng nói xong, không cần bấm mic lần nữa', (tester) async {
      await pumpChat(tester);
      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pump();
      expect(find.textContaining('nói xong mình sẽ tự gửi'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-level')), findsOneWidget);

      for (final db in [...List.filled(5, -50.0), ...List.filled(10, -20.0), ...List.filled(16, -50.0)]) {
        recorder.levelController.add(db);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(recorder.stopCalls, 1);
      expect(assistant.voiced, [_image]);
      expect(find.textContaining('nói xong mình sẽ tự gửi'), findsNothing);
      expect(find.byKey(const ValueKey('voice-level')), findsNothing);
    });

    testWidgets('không ai nói trong 8 giây: dừng, hủy bản ghi và báo chưa nghe thấy gì, không gửi', (tester) async {
      await pumpChat(tester);
      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pump();

      for (var i = 0; i < 81; i++) {
        recorder.levelController.add(-50);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpAndSettle();

      expect(recorder.cancelCalls, 1);
      expect(assistant.voiced, isEmpty);
      expect(find.textContaining('Mình chưa nghe thấy gì'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-level')), findsNothing);
    });

    testWidgets('bị từ chối quyền micro: báo hướng dẫn, không ghi', (tester) async {
      recorder.startResult = VoiceStart.denied;
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cần quyền micro để ghi âm'), findsOneWidget);
      expect(find.textContaining('Đang nghe'), findsNothing);
    });

    testWidgets('không bật được micro: báo và vẫn gõ được', (tester) async {
      recorder.startResult = VoiceStart.failed;
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không bật được micro'), findsOneWidget);
    });

    testWidgets('dừng mà không có tệp: báo "chưa nghe thấy gì", không gửi', (tester) async {
      recorder.path = null;
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mình chưa nghe thấy gì'), findsOneWidget);
      expect(assistant.voiced, isEmpty);
    });

    testWidgets('startWith=voice tự bắt đầu ghi đúng một lần', (tester) async {
      await pumpChat(tester, startWith: 'voice');

      expect(recorder.startCalls, 1);
      expect(find.textContaining('Đang nghe'), findsOneWidget);
    });

    testWidgets('rời màn hình khi đang ghi: hủy bản ghi', (tester) async {
      await pumpChat(tester);
      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());

      expect(recorder.cancelCalls, 1);
    });

    testWidgets('bấm quét: chọn nguồn ảnh trong sheet rồi gửi ảnh vào chat', (tester) async {
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      expect(find.text('Quét bill'), findsOneWidget);
      expect(find.text('Chụp ảnh'), findsOneWidget);
      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pumpAndSettle();

      expect(images.galleryCalls, 1);
      expect(assistant.scanned, [_image]);
    });

    testWidgets('"Quét bill" mở bộ quét tự động, "Chụp ảnh" chỉ mở camera thường', (tester) async {
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quét bill'));
      await tester.pumpAndSettle();
      expect((images.scanCalls, images.cameraCalls), (1, 0));

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chụp ảnh'));
      await tester.pumpAndSettle();
      expect((images.scanCalls, images.cameraCalls), (1, 1));
    });

    testWidgets('ảnh từ "Quét bill" và từ "Chụp ảnh" đều được gửi vào chat', (tester) async {
      images.scanPath = '/tmp/scanned.jpg';
      images.cameraPath = '/tmp/photo.jpg';
      await pumpChat(tester);

      for (final label in ['Quét bill', 'Chụp ảnh']) {
        await tester.tap(find.byKey(const ValueKey('scan-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      expect(assistant.scanned, ['/tmp/scanned.jpg', '/tmp/photo.jpg']);
    });

    testWidgets('đã tắt AI trong Hồ sơ: bấm quét mở thẳng chọn ảnh, không hỏi đồng ý, và vẫn gửi ảnh', (tester) async {
      consent.user = consentTestUser(terms: true); // AI tắt: chỉ dùng luật, không phải rào chặn
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      expect(find.text('Phân loại chi tiêu bằng AI'), findsNothing);
      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);

      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pumpAndSettle();
      expect(assistant.scanned, [_image]);
      expect(consent.calls, isEmpty);
    });

    testWidgets('mở chat bằng start=scan khi AI tắt: mở thẳng chọn ảnh, không hỏi gì', (tester) async {
      consent.user = consentTestUser(terms: true);
      await pumpChat(tester, startWith: 'scan');

      expect(find.text('Phân loại chi tiêu bằng AI'), findsNothing);
      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);
    });

    testWidgets('đã tắt AI: gửi tin nhắn không hỏi đồng ý (chỉ dùng luật), tin sau cũng vậy', (tester) async {
      consent.user = consentTestUser(terms: true);
      await pumpChat(tester);

      for (final text in ['mua ổ cắm điện 60k', 'cafe 30k']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('send-button')));
        await tester.pumpAndSettle();
        expect(find.text('Phân loại chi tiêu bằng AI'), findsNothing);
      }

      expect(assistant.sent, [('mua ổ cắm điện 60k', DraftSource.chat), ('cafe 30k', DraftSource.chat)]);
      expect(consent.calls, isEmpty);
    });

    testWidgets('đã tắt AI: ghi âm xong gửi giọng nói ngay, không hỏi đồng ý', (tester) async {
      consent.user = consentTestUser(terms: true);
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();

      expect(find.text('Phân loại chi tiêu bằng AI'), findsNothing);
      expect(assistant.voiced, [_image]);
    });

    testWidgets('đã đồng ý AI: gửi tin nhắn không hỏi gì thêm', (tester) async {
      await pumpChat(tester);

      await tester.enterText(find.byType(TextField), 'cafe 30k');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-button')));
      await tester.pumpAndSettle();

      expect(find.text('Phân loại chi tiêu bằng AI'), findsNothing);
      expect(assistant.sent, [('cafe 30k', DraftSource.chat)]);
    });

    testWidgets('hủy chọn ảnh: không gửi gì', (tester) async {
      images.galleryPath = null;
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pumpAndSettle();

      expect(assistant.scanned, isEmpty);
    });

    testWidgets('từ chối quyền camera: báo thông điệp của nguồn ảnh', (tester) async {
      images.error = const ImageSourceException('Cần quyền camera để chụp hóa đơn.');
      await pumpChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chụp ảnh'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cần quyền camera để chụp hóa đơn.'), findsOneWidget);
      expect(assistant.scanned, isEmpty);
    });

    testWidgets('startWith=scan tự mở chọn nguồn ảnh', (tester) async {
      await pumpChat(tester, startWith: 'scan');

      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);
    });
  });

  group('AssistantController.scanReceipt: ảnh chụp màn hình nhiều đơn', () {
    ReceiptScan orderList({int incomplete = 0, int n = 3}) {
      final base = ReceiptScan.fromJson(fixtureData('scan_receipt_order_list') as Map<String, dynamic>);
      return ReceiptScan(success: true, draft: base.draft, orders: base.orders.take(n).toList(), incompleteOrders: incomplete);
    }

    test('nhiều đơn: MỘT thẻ gộp để xác nhận một lần, kèm một dòng báo số đơn, không ghi gì', () async {
      final c = AssistantController(repository: _ScanRepo([() => orderList()]));

      await c.scanReceipt(_image);

      final m = c.state.messages;
      expect(m.map((e) => e.runtimeType), [ImageNote, AssistantText, DraftBatchCard]);
      expect((m[1] as AssistantText).text, allOf(contains('3 đơn'), contains('Lưu tất cả')));
      expect(m.whereType<DraftBatchCard>().single.drafts.map((d) => d.amountCents), [BigInt.from(78742), BigInt.from(224400), BigInt.from(247253)]);
      expect(m.map((e) => e.id).toSet(), hasLength(3));
    });

    test('Lưu tất cả: ví đang chọn được gắn cho mọi đơn, mỗi đơn một giao dịch nguồn Receipt, mỗi đơn giữ tên cửa hàng của nó', () async {
      final saved = <List<DraftSave>>[];
      final saver = DraftSaver(
        categoryIdOf: (slug) => 'cat-$slug',
        save: (d, {required categoryId, required accountId, required clientRequestId}) async => throw StateError('dùng saveAll'),
        saveAll: (items) async => saved.add(items),
        syncNow: () async {},
      );
      final c = AssistantController(repository: _ScanRepo([() => orderList()]), saver: saver);
      c.selectAccount('acc-1');

      await c.scanReceipt(_image);
      final batch = c.state.messages.whereType<DraftBatchCard>().single;
      expect(batch.allComplete, isTrue);
      await c.confirmBatch(batch.id);

      expect(saved.single.map((i) => (i.draft.amountCents, i.draft.merchantName, i.draft.source, i.accountId, i.categoryId)), [
        (BigInt.from(78742), 'nlp shop LIv B', DraftSource.receipt, 'acc-1', 'cat-shopping'),
        (BigInt.from(224400), 'Cow&Kitty', DraftSource.receipt, 'acc-1', 'cat-shopping'),
        (BigInt.from(247253), "Mommy's Joy", DraftSource.receipt, 'acc-1', 'cat-shopping'),
      ]);
      expect(c.state.messages.whereType<DraftBatchCard>().single.resolved, isTrue);
    });

    test('có đơn bị cắt dở: nói rõ để người dùng chụp phần còn lại', () async {
      final c = AssistantController(repository: _ScanRepo([() => orderList(incomplete: 1)]));

      await c.scanReceipt(_image);

      expect((c.state.messages[1] as AssistantText).text, contains('1 đơn'));
      expect((c.state.messages[1] as AssistantText).text, contains('cắt'));
    });

    test('chỉ một đơn thì vẫn là một thẻ nháp như quét thường', () async {
      final c = AssistantController(repository: _ScanRepo([() => orderList(n: 1)]));

      await c.scanReceipt(_image);

      expect(c.state.messages.whereType<DraftCard>(), hasLength(1));
      expect(c.state.messages.whereType<AssistantText>(), isEmpty);
    });
  });
}
