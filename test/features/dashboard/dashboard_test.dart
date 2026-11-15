import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/dashboard/presentation/screens/home_screen.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';

class MockAuthController extends StateNotifier<AsyncValue<UserProfile?>>
    implements AuthController {
  MockAuthController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTransactionController
    extends StateNotifier<AsyncValue<List<TransactionEntity>>>
    implements TransactionController {
  MockTransactionController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAccountsController extends StateNotifier<AsyncValue<List<FinancialAccount>>>
    implements AccountsController {
  MockAccountsController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _accounts = [
  FinancialAccount(id: 'a1', type: AccountType.bank, name: 'Vietcombank', balanceCents: BigInt.from(30955000)),
  FinancialAccount(id: 'a2', type: AccountType.cash, name: 'Ví tiền mặt', balanceCents: BigInt.from(4000000)),
];

final _summary = MonthlySummary(
  totalSpentCents: BigInt.from(45000),
  totalIncomeCents: BigInt.from(20000000),
  netCents: BigInt.from(19955000),
  prevMonthSpentCents: BigInt.zero,
  transactionCount: 3,
  changePercent: null,
);

void main() {
  final mockUser = UserProfile(
    id: 'usr-1',
    email: 'alex@finmate.com',
    displayName: 'Alex Rivers',
    isEmailVerified: true,
    notificationPrefs: NotificationPrefs.defaultPrefs(),
    createdAt: DateTime.now(),
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    List<FinancialAccount>? accounts,
    Future<MonthlySummary> Function()? summary,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => MockAuthController(AsyncValue.data(mockUser))),
          transactionControllerProvider.overrideWith((ref) => MockTransactionController(const AsyncValue.data([]))),
          accountsControllerProvider.overrideWith((ref) => MockAccountsController(AsyncValue.data(accounts ?? _accounts))),
          monthlySummaryProvider.overrideWith((ref) => (summary ?? () async => _summary)()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomeScreen & Dashboard Tests', () {
    testWidgets('hiển thị chào người dùng, các lối tắt và không còn linh vật', (tester) async {
      await pumpHome(tester);

      expect(find.text('Alex Rivers'), findsOneWidget);
      expect(find.text('TỔNG TÀI SẢN KHẢ DỤNG'), findsOneWidget);
      expect(find.text('Finny'), findsNothing);
      expect(find.textContaining('Hỏi FinMate'), findsOneWidget);
      expect(find.text('Ghi chép'), findsOneWidget);
      expect(find.text('Kế hoạch'), findsNWidgets(2));
      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
    });

    testWidgets('số dư = tổng số dư các tài khoản; thu/chi tháng lấy từ báo cáo (không số giả)', (tester) async {
      await pumpHome(tester);

      expect(find.text('34.955.000 ₫'), findsOneWidget);
      expect(find.text('+20.000.000 ₫'), findsOneWidget);
      expect(find.text('-45.000 ₫'), findsOneWidget);
      expect(find.textContaining('24.500.000'), findsNothing);
      expect(find.textContaining('18.500.000'), findsNothing);
    });

    testWidgets('chưa có tài khoản: số dư 0 kèm gợi ý tạo ví', (tester) async {
      await pumpHome(tester, accounts: const []);

      expect(find.text('0 ₫'), findsWidgets);
      expect(find.textContaining('chưa có tài khoản'), findsOneWidget);
    });

    testWidgets('lỗi tải báo cáo: không hiện số giả, có nút Thử lại', (tester) async {
      await pumpHome(tester, summary: () async => throw Exception('Không có kết nối mạng'));

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('+20.000.000 ₫'), findsNothing);
      expect(find.textContaining('18.500.000'), findsNothing);
    });

    testWidgets('danh sách giao dịch trống hiện chữ "Chưa có giao dịch nào" (không nói "hôm nay")', (tester) async {
      await pumpHome(tester);

      expect(find.textContaining('Chưa có giao dịch nào'), findsOneWidget);
      expect(find.textContaining('hôm nay'), findsNothing);
    });
  });
}
