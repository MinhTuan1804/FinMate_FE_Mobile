// Kiểm chứng hợp đồng với backend THẬT. Chỉ chạy khi đặt biến môi trường (mặc định bị bỏ qua):
//   FINMATE_BASE_URL (ví dụ http://localhost:8080), FINMATE_TEST_EMAIL, FINMATE_TEST_PASSWORD
// Dùng một tài khoản thử đã xác thực email; test tạo rồi xóa một giao dịch 1.000 ₫.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/auth/data/auth_repository.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/planning/data/planning_repository.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  final env = Platform.environment;
  final baseUrl = env['FINMATE_BASE_URL'];
  final email = env['FINMATE_TEST_EMAIL'];
  final password = env['FINMATE_TEST_PASSWORD'];
  final skip = (baseUrl == null || email == null || password == null)
      ? 'Đặt FINMATE_BASE_URL, FINMATE_TEST_EMAIL, FINMATE_TEST_PASSWORD để chạy test với backend thật'
      : null;

  test('mọi repository đọc được response thật của backend và tạo/đọc giao dịch đúng hợp đồng', () async {
    final storage = InMemoryTokenStorage();
    final client = ApiClient(baseUrl: baseUrl!, tokenStorage: storage);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();

    // Đăng nhập: response chỉ có token, hồ sơ lấy từ users/me
    final user = await AuthRepository(apiClient: client, tokenStorage: storage).login(email: email!, password: password!);
    expect(user.email, email);
    expect(user.isEmailVerified, isTrue);

    // resend-verification trả 204 không có nội dung: không được coi là lỗi
    await AuthRepository(apiClient: client, tokenStorage: storage).resendVerification(email: email);

    final accountsRepo = AccountsRepository(apiClient: client);
    final accounts = await accountsRepo.getAccounts();
    expect(accounts, isNotEmpty, reason: 'tài khoản thử cần có ít nhất một tài khoản');
    expect(await accountsRepo.getProviders(), isNotEmpty);
    expect(await CategoriesRepository(apiClient: client).getCategories(), isNotEmpty);

    final planning = PlanningRepository(apiClient: client);
    await planning.getBudgets(month: now.month, year: now.year);
    await planning.getGoals();

    final reports = ReportsRepository(apiClient: client);
    await reports.getMonthlySummary(year: now.year, month: now.month);
    await reports.getCategoryBreakdown(year: now.year, month: now.month);
    await reports.getForecast();

    // Tạo giao dịch thật rồi kiểm tra nó xuất hiện ở trang đầu, cuối cùng xóa để không để lại dữ liệu
    final txRepo = TransactionRepository(apiClient: client, database: db);
    final created = await txRepo.createTransaction(
      accountId: accounts.first.id,
      amountCents: BigInt.from(1000),
      type: TransactionType.expense,
      description: 'live-contract-test',
      date: now,
    );
    addTearDown(() => client.delete('/api/v1/transactions/${created.id}'));

    expect(created.isSynced, isTrue, reason: 'server phải nhận giao dịch (không rơi vào hàng đợi offline)');
    final page = await txRepo.getTransactions(limit: 20);
    expect(page.items.any((t) => t.id == created.id), isTrue);
    expect(page.items.firstWhere((t) => t.id == created.id).amountCents, BigInt.from(1000));

    // AI: chatbot, parse, quét hóa đơn. Mọi giao dịch chat tạo ra đều bị xóa khi test kết thúc
    final assistant = AssistantRepository(apiClient: client);
    final chatCreated = <String>{};
    addTearDown(() async {
      for (final id in chatCreated) {
        await client.delete('/api/v1/transactions/$id');
      }
    });

    final requestId = const Uuid().v4();
    final first = await assistant.chat('an trua 45k', accountId: accounts.first.id, clientRequestId: requestId);
    expect([ChatAction.saved, ChatAction.confirm], contains(first.action));
    if (first.transaction != null) chatCreated.add(first.transaction!.id);

    // Gửi lại cùng clientRequestId: ghi nhận backend có chống trùng cho /chat không
    final second = await assistant.chat('an trua 45k', accountId: accounts.first.id, clientRequestId: requestId);
    if (second.transaction != null) chatCreated.add(second.transaction!.id);
    // ignore: avoid_print
    print('chat idempotency: lần 1=${first.action.name}/${first.transaction?.id}, lần 2=${second.action.name}/${second.transaction?.id}, số giao dịch tạo ra=${chatCreated.length}');

    final summary = await assistant.chat('tháng này tôi tiêu bao nhiêu', accountId: accounts.first.id);
    expect(summary.action, ChatAction.summary);
    expect(summary.summary, isNotNull);

    final parsed = await assistant.parse('an trua com tam 45k');
    expect(parsed.amountCents, BigInt.from(45000));

    final scan = await assistant.scanReceipt('test/fixtures/receipt_sample.png');
    expect(scan.success, isTrue);
  }, skip: skip, timeout: const Timeout(Duration(seconds: 120)));
}
