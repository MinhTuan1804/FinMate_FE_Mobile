import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/data/voice_recorder.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/main.dart';
import '../fixtures/fakes.dart';
import '../fixtures/fixture.dart';

/// Backend giả có trạng thái, dùng response thật đã lưu ở test/fixtures/api
class _FakeBackend {
  int? income;
  final List<Map<String, dynamic>> accounts = [];
  final List<String> calls = [];
  bool loginFails = false;

  /// Độ trễ mạng giả của mọi request (mặc định không trễ)
  Duration latency = Duration.zero;
  bool refreshFails = true;
  bool sessionExpired = false;
  final List<Map<String, dynamic>> transactions = [];
  final List<String> chatTexts = [];
  final List<String> createdSources = [];
  final List<Object?> createdScanIds = [];
  final List<Object?> createdGroups = [];

  /// Mọi POST /transactions (kể cả lần gửi lại): nhóm hóa đơn và clientRequestId
  final List<(Object?, Object?)> postedRequests = [];
  final Map<Object, Map<String, dynamic>> _byRequestId = {};
  String scanFixture = 'scan_receipt_success';

  /// Đồng ý điều khoản / gửi tên món cho AI của tài khoản này; mặc định đã đồng ý để các luồng khác không bị chặn
  bool termsAccepted = true;
  bool aiConsent = true;
  bool aiOptedOut = false;
  final List<String> consentCalls = [];

  /// Nhóm hóa đơn mà lần POST kế tiếp bị máy chủ từ chối (500), mỗi nhóm một lần
  final Set<String> failGroupsOnce = {};

  Map<String, dynamic> _createTransaction(Map body, {required String source, String? description, String? categoryName}) {
    final account = accounts.firstWhere((a) => a['id'] == body['financialAccountId']);
    final delta = body['transactionType'] == 'Debit' ? -(body['amountCents'] as int) : (body['amountCents'] as int);
    account['balanceCents'] = (account['balanceCents'] as int) + delta;
    createdSources.add(source);
    createdScanIds.add(body['receiptScanId']);
    createdGroups.add(body['receiptGroup']);
    final tx = {
      'id': 'tx-${transactions.length}',
      'financialAccountId': account['id'],
      'counterAccountId': null,
      'categoryId': body['categoryId'],
      'categoryName': categoryName,
      'amountCents': body['amountCents'],
      'transactionType': body['transactionType'],
      'source': source,
      'status': 'Confirmed',
      'merchantName': null,
      'description': description ?? body['description'],
      'transactedAt': body['transactedAt'],
      'balanceAfterCents': account['balanceCents'],
      'createdAt': body['transactedAt'],
    };
    transactions.insert(0, tx);
    return tx;
  }

  /// Chatbot giả: "cafe"/"phở" tự ghi; "luong" trả bản nháp thiếu danh mục
  Map<String, dynamic> _chat(Map body) {
    final text = body['text'] as String;
    chatTexts.add(text);
    final accountId = body['financialAccountId'] ?? accounts.first['id'];
    if (text.contains('chuyen')) {
      // "chuyển 2 triệu sang tiết kiệm": thẻ chuyển tiền chưa chọn ví nguồn/đích
      return {
        'action': 'confirm',
        'intent': 'transfer_money',
        'draft': {'kind': 'transfer', 'amountCents': 2000000, 'transactionType': 'transfer', 'description': 'chuyển sang tiết kiệm', 'missingFields': ['accounts']},
      };
    }
    if (text.contains('luong')) {
      return {
        'action': 'confirm',
        'intent': 'add_expense',
        'draft': {
          'kind': 'expense',
          'amountCents': 20000000,
          'transactionType': 'debit',
          'description': 'luong',
          'suggestedFinancialAccountId': accountId,
          'missingFields': ['category'],
        },
      };
    }
    final amount = text.contains('cafe') ? 55000 : 45000;
    final tx = _createTransaction(
      {'financialAccountId': accountId, 'amountCents': amount, 'transactionType': 'Debit', 'transactedAt': '2026-10-09T12:00:00Z'},
      source: 'Manual',
      description: text,
      categoryName: 'Ăn uống',
    );
    return {'action': 'saved', 'intent': 'add_expense', 'transaction': tx};
  }

  Map<String, dynamic> get me => {
        ...(fixtureData('users_me') as Map<String, dynamic>),
        'monthlyIncomeCents': income,
        'termsAccepted': termsAccepted,
        'aiConsentGranted': aiConsent,
      };

  ResponseBody handle(RequestOptions o) {
    calls.add('${o.method} ${o.path}');
    final path = o.path.replaceFirst('/api/v1', '');
    ResponseBody ok(Object? data) => respondJson({'success': true, 'data': data, 'error': null, 'meta': {'cursor': null}});

    switch ((o.method, path)) {
      case ('POST', '/auth/login'):
        return loginFails
            ? respondJson({'success': false, 'data': null, 'error': {'code': 'AUTH_INVALID_CREDENTIALS', 'message': 'Email hoặc mật khẩu không đúng.'}}, status: 401)
            : respondFixture('login');
      case ('POST', '/auth/register'):
        return ok(me);
      case ('POST', '/auth/verify-email'):
        return ok(null);
      case ('POST', '/auth/refresh'):
        return refreshFails
            ? respondJson({'success': false, 'data': null, 'error': {'code': 'AUTH_INVALID_REFRESH', 'message': 'Phiên hết hạn.'}}, status: 401)
            : respondFixture('login');
      case ('GET', '/users/me'):
        if (sessionExpired) return respondJson({'success': false, 'data': null, 'error': {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Hết hạn.'}}, status: 401);
        return ok(me);
      case ('POST', '/transactions'):
        final body = o.data as Map;
        postedRequests.add((body['receiptGroup'], body['clientRequestId']));
        // Như BE thật: gửi lại cùng clientRequestId trả về giao dịch đã có, không tạo mới
        final replay = _byRequestId[body['clientRequestId'] ?? ''];
        if (replay != null) return ok(replay);
        if (failGroupsOnce.remove(body['receiptGroup'])) {
          return respondJson({'success': false, 'data': null, 'error': {'code': 'INTERNAL_ERROR', 'message': 'Máy chủ đang bận, thử lại sau.'}}, status: 500);
        }
        final created = _createTransaction(body, source: body['source'] as String? ?? 'Manual');
        if (body['clientRequestId'] != null) _byRequestId[body['clientRequestId'] as Object] = created;
        return ok(created);
      case ('POST', '/transactions/transfer'):
        final body = o.data as Map;
        final from = accounts.firstWhere((a) => a['id'] == body['fromAccountId']);
        final to = accounts.firstWhere((a) => a['id'] == body['toAccountId']);
        from['balanceCents'] = (from['balanceCents'] as int) - (body['amountCents'] as int);
        to['balanceCents'] = (to['balanceCents'] as int) + (body['amountCents'] as int);
        final tx = {
          'id': 'tx-${transactions.length}',
          'financialAccountId': from['id'],
          'counterAccountId': to['id'],
          'categoryId': null,
          'categoryName': null,
          'amountCents': body['amountCents'],
          'transactionType': 'Transfer',
          'source': 'Manual',
          'status': 'Confirmed',
          'merchantName': null,
          'description': body['description'],
          'transactedAt': body['transactedAt'],
          'balanceAfterCents': from['balanceCents'],
          'createdAt': body['transactedAt'],
        };
        transactions.insert(0, tx);
        return ok(tx);
      case ('POST', '/transactions/chat'):
        return ok(_chat(o.data as Map));
      case ('POST', '/transactions/voice'):
        // STT giả "nghe" ra câu cố định, rồi đi qua chatbot giả như câu gõ tay
        return ok({'transcript': 'ăn phở 45k', 'chat': _chat({'text': 'ăn phở 45k'})});
      case ('POST', '/transactions/scan-receipt'):
        return ok(fixtureData(scanFixture));
      case ('POST', '/users/me/consents'):
        final body = o.data as Map;
        consentCalls.add('accept:${body['kind']}:${body['version']}');
        if (body['kind'] == 'terms') {
          termsAccepted = true;
          if (!aiOptedOut) aiConsent = true; // điều khoản đã nêu việc gửi tên món cho AI nên đồng ý điều khoản cũng bật AI
        }
        if (body['kind'] == 'ai') aiConsent = true;
        return ok(me);
      case ('DELETE', '/users/me/consents/ai'):
        consentCalls.add('withdraw:ai');
        aiConsent = false;
        aiOptedOut = true;
        return ok(me);
      case ('PATCH', '/users/me'):
        income = (o.data as Map)['monthlyIncomeCents'] as int? ?? income; // null = giữ nguyên, như BE
        return ok(me);
      case ('GET', '/financial-accounts'):
        return ok(accounts);
      case ('POST', '/financial-accounts'):
        final body = o.data as Map;
        final created = {
          'id': 'acc-${accounts.length}',
          'accountType': body['accountType'],
          'accountName': body['accountName'],
          'providerDisplayName': null,
          'isMonitored': true,
          'balanceCents': body['initialBalanceCents'],
        };
        accounts.add(created);
        return ok(created);
      case ('GET', '/financial-accounts/providers'):
        return respondFixture('account_providers');
      case ('GET', '/categories'):
        return respondFixture('categories');
      case ('GET', '/budgets'):
        return ok({'periodStart': '2026-09-01', 'periodEnd': '2026-10-01', 'totalBudget': null, 'categoryBudgets': []});
      case ('GET', '/saving-goals'):
        return ok([]);
      case ('GET', '/transactions'):
        return ok(transactions);
      case ('GET', '/reports/monthly-summary'):
        return respondFixture('monthly_summary');
      case ('GET', '/reports/category-breakdown'):
        return respondFixture('category_breakdown');
      case ('GET', '/reports/forecast'):
        return respondFixture('forecast');
      default:
        return respondJson({'success': false, 'data': null, 'error': {'code': 'NOT_FOUND', 'message': 'Không có ${o.method} $path'}}, status: 404);
    }
  }
}

void main() {
  late _FakeBackend backend;
  late InMemoryTokenStorage storage;
  late AppDatabase db;

  setUp(() {
    backend = _FakeBackend();
    storage = InMemoryTokenStorage();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> launch(WidgetTester tester, {VoiceRecorder? recorder, ReceiptImageSource? imageSource}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        databaseProvider.overrideWithValue(db),
        if (recorder != null) voiceRecorderProvider.overrideWithValue(recorder),
        if (imageSource != null) receiptImageSourceProvider.overrideWithValue(imageSource),
        apiClientProvider.overrideWith((ref) => ApiClient(
              tokenStorage: storage,
              customDio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = RouteAdapter(backend.handle, delayOf: (_) => backend.latency),
              onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).state = true,
            )),
      ],
      child: const FinMateApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> loginFromWelcome(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Đăng nhập với Email'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'probe@example.com');
    await tester.enterText(fields.at(1), 'Password123!');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
  }

  testWidgets('người dùng mới: Welcome -> đăng nhập -> onboarding -> tạo ví -> Trang chủ', (tester) async {
    await launch(tester);
    expect(find.text('Cam kết bảo mật Zero-Credential'), findsOneWidget);

    await loginFromWelcome(tester);
    // Chưa có thu nhập nên router đưa vào onboarding
    expect(find.textContaining('Thiết lập ban đầu'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '15.000.000');
    await tester.tap(find.text('Hoàn tất & Khám phá FinMate'));
    await tester.pumpAndSettle();

    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Probe'), findsOneWidget);
    expect(backend.income, 15000000);
    expect(backend.accounts.single['accountType'], 'Cash');
    // Số dư lấy từ tài khoản vừa tạo (0 ₫), không phải số cứng cũ
    expect(find.textContaining('24.500.000'), findsNothing);
    expect(storage.hasAccessToken(), completion(isTrue));
  });

  testWidgets('chưa đồng ý điều khoản: đăng nhập xong bị giữ ở màn điều khoản, đồng ý rồi mới vào onboarding', (tester) async {
    backend.termsAccepted = false;
    await launch(tester);

    await loginFromWelcome(tester);
    expect(find.text('Trước khi bắt đầu'), findsOneWidget);
    expect(find.textContaining('Thiết lập ban đầu'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(backend.consentCalls, ['accept:terms:2']);
    expect(backend.aiConsent, isTrue); // một lần đồng ý điều khoản là đủ để dùng AI
    expect(find.textContaining('Thiết lập ban đầu'), findsOneWidget);
  });

  testWidgets('mở lại app khi chưa đồng ý điều khoản (ví dụ chính sách vừa đổi): vào thẳng màn điều khoản', (tester) async {
    backend.income = 15000000;
    backend.termsAccepted = false;
    await storage.saveTokens(accessToken: 'access-token', refreshToken: 'refresh-token');
    await launch(tester);

    expect(find.text('Trước khi bắt đầu'), findsOneWidget);
    expect(find.text('Xin chào,'), findsNothing);
  });

  testWidgets('người dùng đã có thu nhập: đăng nhập vào thẳng Trang chủ', (tester) async {
    backend.income = 15000000;
    backend.accounts.add({'id': 'a1', 'accountType': 'Cash', 'accountName': 'Ví', 'providerDisplayName': null, 'isMonitored': true, 'balanceCents': 4000000});
    await launch(tester);

    await loginFromWelcome(tester);

    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('4.000.000 ₫'), findsOneWidget);
  });

  testWidgets('mở lại app khi đã có token: splash rồi vào thẳng Trang chủ, không qua Welcome', (tester) async {
    backend.income = 15000000;
    await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

    await launch(tester);

    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Cam kết bảo mật Zero-Credential'), findsNothing);
  });

  testWidgets('đăng nhập sai: ở lại màn đăng nhập và hiện thông điệp của server', (tester) async {
    backend.loginFails = true;
    await launch(tester);

    await loginFromWelcome(tester);

    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
  });

  testWidgets('đăng xuất: báo còn giao dịch chưa gửi, GIỮ chúng trên máy, xóa token và về Welcome', (tester) async {
    backend.income = 15000000;
    await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
    await db.enqueueSync(SyncQueueCompanion.insert(clientRequestId: 'x', endpoint: '/e', payload: '{}', createdAt: DateTime.now()));
    await launch(tester);
    expect(find.text('Xin chào,'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.circleUser));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Còn giao dịch chưa đồng bộ'), findsOneWidget);
    expect(find.textContaining('giữ trên máy'), findsOneWidget); // không còn nói "sẽ làm mất"

    await tester.tap(find.text('Vẫn đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Cam kết bảo mật Zero-Credential'), findsOneWidget);
    expect(await db.pendingSyncCount(), 1); // dữ liệu chưa đồng bộ của người dùng phải sống sót qua đăng xuất
    expect(await storage.hasAccessToken(), isFalse);
  });

  testWidgets('đăng xuất rồi đăng nhập lại: không thấy dữ liệu cục bộ của phiên trước', (tester) async {
    backend.income = 15000000;
    await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
    await launch(tester);
    await tester.tap(find.byIcon(LucideIcons.circleUser));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Cam kết bảo mật Zero-Credential'), findsOneWidget);

    await loginFromWelcome(tester);

    expect(find.text('Xin chào,'), findsOneWidget);
    expect(await db.getAllTransactions(), isEmpty);
  });

  testWidgets('đăng ký -> OTP -> (server không cấp token) -> về đăng nhập với email điền sẵn -> vào app', (tester) async {
    await launch(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Tạo tài khoản mới'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Probe');
    await tester.enterText(fields.at(1), 'probe@example.com');
    await tester.enterText(fields.at(2), 'Password123!');
    await tester.enterText(fields.at(3), 'Password123!');
    await tester.tap(find.text('Đăng ký tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Xác thực Email'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.textContaining('Email đã được xác thực'), findsOneWidget);
    expect(find.text('probe@example.com'), findsOneWidget);
  });

  testWidgets('mở app với token đã hết hạn (refresh bị từ chối): về Welcome và xóa token', (tester) async {
    backend.sessionExpired = true;
    await storage.saveTokens(accessToken: 'old', refreshToken: 'old');

    await launch(tester);

    expect(find.text('Cam kết bảo mật Zero-Credential'), findsOneWidget);
    expect(await storage.hasAccessToken(), isFalse);
  });

  testWidgets('phiên hết hạn lúc mở app: thông báo "hết hạn" hiện ở màn đăng nhập đúng một lần', (tester) async {
    backend.sessionExpired = true;
    await storage.saveTokens(accessToken: 'old', refreshToken: 'old');
    await launch(tester);
    backend.sessionExpired = false;

    Future<void> openLogin() async {
      await tester.tap(find.text('Đăng nhập với Email'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await openLogin();
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsOneWidget);

    // Quay lại rồi mở lại: đã báo rồi nên không lặp lại
    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();
    await openLogin();
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsNothing);
  });

  testWidgets('ghi giao dịch chi tiêu từ Trang chủ: gọi API đúng, số dư và danh sách được làm mới', (tester) async {
    backend.income = 15000000;
    backend.accounts.add({'id': 'a1', 'accountType': 'Cash', 'accountName': 'Ví', 'providerDisplayName': null, 'isMonitored': true, 'balanceCents': 4000000});
    await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
    await launch(tester);
    expect(find.text('4.000.000 ₫'), findsOneWidget);
    final accountLoadsBefore = backend.calls.where((c) => c == 'GET /api/v1/financial-accounts').length;

    await tester.tap(find.text('Ghi chép'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thủ công'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VNĐ)'), '500.000');
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('POST /api/v1/transactions'));
    expect(backend.transactions.single['amountCents'], 500000);
    expect(backend.transactions.single['transactionType'], 'Debit');
    expect(backend.calls.where((c) => c == 'GET /api/v1/financial-accounts').length, greaterThan(accountLoadsBefore));
    expect(find.text('3.500.000 ₫'), findsOneWidget);
  });

  group('trợ lý AI', () {
    Future<void> startWithAccount(WidgetTester tester, {VoiceRecorder? recorder, ReceiptImageSource? imageSource}) async {
      backend.income = 15000000;
      backend.accounts.add({'id': 'a1', 'accountType': 'Cash', 'accountName': 'Ví', 'providerDisplayName': null, 'isMonitored': true, 'balanceCents': 4000000});
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
      await launch(tester, recorder: recorder, imageSource: imageSource);
    }

    Future<void> openChat(WidgetTester tester) async {
      await tester.tap(find.textContaining('Hỏi FinMate'));
      await tester.pumpAndSettle();
    }

    Future<void> sendText(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-button')));
      await tester.pumpAndSettle();
    }

    Future<void> saveReview(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Xác nhận & Lưu giao dịch'));
      await tester.tap(find.text('Xác nhận & Lưu giao dịch'));
      await tester.pumpAndSettle();
    }

    testWidgets('(a) nhắn "cafe 55k": thẻ đã ghi và số dư Trang chủ giảm', (tester) async {
      await startWithAccount(tester);
      await openChat(tester);

      await sendText(tester, 'cafe 55k');

      expect(find.text('Đã ghi giao dịch'), findsOneWidget);
      expect(backend.chatTexts, ['cafe 55k']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('3.945.000 ₫'), findsOneWidget);
    });

    testWidgets('(b) "luong 20 trieu": thẻ nháp thiếu danh mục, đổi sang Thu nhập rồi lưu với source Manual, số dư tăng', (tester) async {
      await startWithAccount(tester);
      await openChat(tester);

      await sendText(tester, 'luong 20 trieu');
      expect(find.textContaining('Cần bổ sung'), findsOneWidget);
      await tester.tap(find.text('Xem và lưu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Thu nhập'));
      await tester.pump();
      await saveReview(tester);

      expect(backend.createdSources, ['Manual']);
      expect(backend.createdScanIds, [null]); // giao dịch không từ quét thì không gửi receiptScanId
      expect(backend.transactions.single['transactionType'], 'Credit');
      expect(find.textContaining('Đã ghi: 20.000.000 ₫'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('24.000.000 ₫'), findsOneWidget);
    });

    testWidgets('chuyển 2 triệu sang tiết kiệm: thẻ chuyển tiền, lưu xong không lỗi khung hình và hai số dư đổi', (tester) async {
      backend.accounts.add({'id': 'a2', 'accountType': 'Cash', 'accountName': 'Tiết kiệm', 'providerDisplayName': null, 'isMonitored': true, 'balanceCents': 1000000});
      await startWithAccount(tester);
      await openChat(tester);

      await sendText(tester, 'chuyen 2 trieu sang tiet kiem');
      expect(find.text('Chuyển tiền cần xác nhận'), findsOneWidget);
      await tester.tap(find.text('Xem và lưu'));
      await tester.pumpAndSettle();
      backend.latency = const Duration(milliseconds: 600); // như mạng thật: có khung hình vẽ giữa lúc đang lưu và lúc có phản hồi
      await tester.ensureVisible(find.text('Xác nhận & Lưu giao dịch'));
      await tester.tap(find.text('Xác nhận & Lưu giao dịch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // lỗi thật: '_dependents.isEmpty' ở framework.dart
      expect(find.textContaining('Đã chuyển: 2.000.000 ₫'), findsOneWidget);
      // Chiều chuyển: "sang tiết kiệm" => Tiết kiệm (đứng đầu danh sách) tăng 2 triệu, ví kia giảm 2 triệu (trước đây tiền chạy ngược chiều)
      expect({for (final a in backend.accounts) a['accountName']: a['balanceCents']}, {'Tiết kiệm': 3000000, 'Ví': 2000000});
      expect(backend.transactions.single['transactionType'], 'Transfer');

      // Trên máy thật còn các bước sau lưu: SnackBar tự tắt sau 4 giây, rồi quay về Trang chủ
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('(c) giọng nói: ghi âm gửi lên server, câu nghe được hiện ra và thẻ đã ghi', (tester) async {
      final recorder = FakeVoiceRecorder();
      await startWithAccount(tester, recorder: recorder);
      await openChat(tester);

      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mic-button')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      expect(backend.chatTexts, ['ăn phở 45k']);
      expect(find.text('ăn phở 45k'), findsWidgets);
      expect(find.text('Đã ghi giao dịch'), findsOneWidget);
    });

    testWidgets('quét bill khi đã tắt AI: không hỏi đồng ý, vẫn quét được (chỉ dùng luật)', (tester) async {
      backend.aiConsent = false;
      final images = FakeImageSource(galleryPath: 'test/fixtures/receipt_sample.png');
      await startWithAccount(tester, imageSource: images);
      await openChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      expect(find.text('Phân loại chi tiêu bằng AI'), findsNothing);
      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      expect(backend.consentCalls, isEmpty); // không có lời gọi đồng ý nào
      expect(find.text('55.000 ₫'), findsOneWidget);
    });

    testWidgets('(d) quét hóa đơn: thẻ nháp 55.000 ₫, rà soát rồi lưu với source Receipt', (tester) async {
      final images = FakeImageSource(galleryPath: 'test/fixtures/receipt_sample.png');
      await startWithAccount(tester, imageSource: images);
      await openChat(tester);

      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      expect(find.text('55.000 ₫'), findsOneWidget);
      await tester.tap(find.text('Xem và lưu'));
      await tester.pumpAndSettle();
      await saveReview(tester);

      expect(backend.createdSources, ['Receipt']);
      expect(backend.createdScanIds, ['b7c28f5c-d0a3-45d1-b86d-e6da902f3aa9']); // BE nhận mã lần quét để nối với giao dịch
      expect(backend.transactions.single['amountCents'], 55000);
      expect(backend.createdGroups, [null]); // bill không tách nhóm: không gửi receiptGroup
    });

    Future<void> scanAndOpenReview(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('scan-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem và lưu'));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('saving a split receipt sends one POST per group with receiptScanId, the original receiptGroup and the group amount', (tester) async {
      backend.scanFixture = 'scan_receipt_split';
      await startWithAccount(tester, imageSource: FakeImageSource(galleryPath: 'test/fixtures/receipt_sample.png'));
      await openChat(tester);
      await scanAndOpenReview(tester);

      // Đổi danh mục nhóm "chưa phân loại": receiptGroup vẫn là "unknown"
      await tester.tap(find.text('Đổi danh mục').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mua sắm').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Lưu 2 giao dịch');

      const scanId = '5d1f8a2e-7c3b-4e90-9a61-2b8f0c4d7e13';
      expect(backend.calls.where((c) => c == 'POST /api/v1/transactions'), hasLength(2));
      expect(backend.createdScanIds, [scanId, scanId]);
      expect(backend.createdGroups, ['food', 'unknown']);
      expect(backend.createdSources, ['Receipt', 'Receipt']);
      expect(backend.transactions.reversed.map((t) => t['amountCents']), [100000, 55000]);
      expect(backend.transactions.first['categoryId'], 'd4625fe3-205d-4efc-a294-8db48ac5c971'); // Mua sắm
      expect(find.textContaining('Đã ghi 2 giao dịch'), findsOneWidget);
    });

    testWidgets('second request failure leaves the first saved and retry sends only the failed group', (tester) async {
      backend.scanFixture = 'scan_receipt_split';
      backend.failGroupsOnce.add('unknown');
      await startWithAccount(tester, imageSource: FakeImageSource(galleryPath: 'test/fixtures/receipt_sample.png'));
      await openChat(tester);
      await scanAndOpenReview(tester);

      await tapText(tester, 'Lưu 2 giao dịch');
      expect(backend.createdGroups, ['food']);
      expect(find.text('Máy chủ đang bận, thử lại sau.'), findsOneWidget);
      expect(find.text('Đã lưu'), findsOneWidget);

      await tapText(tester, 'Lưu 1 giao dịch');

      expect(backend.createdGroups, ['food', 'unknown']); // nhóm đầu không bị lưu lần hai
      expect(backend.calls.where((c) => c == 'POST /api/v1/transactions'), hasLength(3));
      expect(find.textContaining('Đã ghi 2 giao dịch'), findsOneWidget);
    });

    testWidgets('reopening the card after leaving resends the same clientRequestIds and the backend dedupes', (tester) async {
      backend.scanFixture = 'scan_receipt_split';
      backend.failGroupsOnce.add('unknown');
      await startWithAccount(tester, imageSource: FakeImageSource(galleryPath: 'test/fixtures/receipt_sample.png'));
      await openChat(tester);
      await scanAndOpenReview(tester);

      await tapText(tester, 'Lưu 2 giao dịch');
      expect(backend.createdGroups, ['food']);
      // Rời màn khi nhóm sau còn lỗi: thẻ chat vẫn cho mở lại
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.text('Xem và lưu'), findsOneWidget);

      await tester.tap(find.text('Xem và lưu'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Lưu 2 giao dịch');

      final food = backend.postedRequests.where((r) => r.$1 == 'food').toList();
      expect(food, hasLength(2));
      expect(food.last.$2, food.first.$2); // cùng clientRequestId
      final unknown = backend.postedRequests.where((r) => r.$1 == 'unknown').toList();
      expect(unknown.last.$2, unknown.first.$2);
      expect(backend.createdGroups, ['food', 'unknown']); // không ghi 'food' hai lần
      expect(backend.transactions, hasLength(2));
      expect(find.textContaining('Đã ghi 2 giao dịch'), findsOneWidget);
    });

    testWidgets('(e) đăng xuất rồi đăng nhập lại: chat trống', (tester) async {
      await startWithAccount(tester);
      await openChat(tester);
      await sendText(tester, 'cafe 55k');
      expect(find.text('Đã ghi giao dịch'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.circleUser));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất tài khoản'));
      await tester.pumpAndSettle();
      await loginFromWelcome(tester);
      await openChat(tester);

      expect(find.text('Đã ghi giao dịch'), findsNothing);
      expect(find.text('Bạn muốn ghi gì hôm nay?'), findsOneWidget);
    });

    testWidgets('(f) màn Cá nhân không còn nội dung gamification', (tester) async {
      await startWithAccount(tester);

      await tester.tap(find.byIcon(LucideIcons.circleUser));
      await tester.pumpAndSettle();

      expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
      for (final word in ['Huy hiệu', 'Thành tựu', 'Cấp độ', 'Chuỗi', 'Finny', 'Điểm']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });
  });
}
