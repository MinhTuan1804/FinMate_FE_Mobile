import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/analytics/presentation/screens/ai_insights_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/cashflow_forecast_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/category_report_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/purchase_check_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/spending_anomalies_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/ai_memory_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:finmate/features/auth/presentation/screens/login_screen.dart';
import 'package:finmate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:finmate/features/auth/presentation/screens/register_screen.dart';
import 'package:finmate/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:finmate/features/auth/presentation/screens/terms_consent_screen.dart';
import 'package:finmate/features/auth/presentation/screens/welcome_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_feed_screen.dart';
import 'package:finmate/features/dashboard/presentation/screens/home_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/alert_thresholds_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/method_detail_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/my_methods_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/recommendation_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/survey_screen.dart';
import 'package:finmate/features/groups/presentation/screens/groups_hub_screen.dart';
import 'package:finmate/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:finmate/features/onboarding/presentation/screens/initial_setup_screen.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/screens/loans_screen.dart';
import 'package:finmate/features/planning/presentation/screens/planning_screen.dart';
import 'package:finmate/features/planning/presentation/screens/recurring_transactions_screen.dart';
import 'package:finmate/features/planning/presentation/screens/savings_goal_detail_screen.dart';
import 'package:finmate/features/profile/presentation/screens/appearance_settings_screen.dart';
import 'package:finmate/features/profile/presentation/screens/backup_export_screen.dart';
import 'package:finmate/features/profile/presentation/screens/category_management_screen.dart';
import 'package:finmate/features/profile/presentation/screens/change_password_screen.dart';
import 'package:finmate/features/profile/presentation/screens/consent_management_screen.dart';
import 'package:finmate/features/profile/presentation/screens/delete_account_screen.dart';
import 'package:finmate/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:finmate/features/profile/presentation/screens/financial_accounts_screen.dart';
import 'package:finmate/features/profile/presentation/screens/legal_document_screen.dart';
import 'package:finmate/features/profile/presentation/screens/profile_screen.dart';
import 'package:finmate/features/profile/presentation/screens/subscription_screen.dart';
import 'package:finmate/features/profile/presentation/screens/support_screen.dart';
import 'package:finmate/features/profile/presentation/screens/support_ticket_detail_screen.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';
import 'package:finmate/features/qr_transfer/presentation/screens/qr_history_screen.dart';
import 'package:finmate/features/qr_transfer/presentation/screens/qr_scan_screen.dart';
import 'package:finmate/features/qr_transfer/presentation/screens/qr_transfer_screen.dart';
import 'package:finmate/features/qr_transfer/presentation/screens/saved_counterparties_screen.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/screens/receipt_scanner_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transaction_detail_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transfer_screen.dart';

const _splashPath = '/splash';
const _termsPath = '/terms';

/// Các màn hình không cần đăng nhập
const _publicPaths = {
  '/',
  '/login',
  '/register',
  '/verify-otp',
  '/forgot-password',
  '/reset-password',
};

/// Các màn hình dành cho khách: người dùng đã đăng nhập sẽ được chuyển đi chỗ khác
const _guestOnlyPaths = {
  _splashPath,
  '/',
  '/login',
  '/register',
  '/verify-otp',
  '/forgot-password',
  '/reset-password',
};

/// Hàm điều hướng có điều kiện theo trạng thái đăng nhập
String? authRedirect(AsyncValue<UserProfile?> auth, String location) {
  if (auth.isLoading) return null;

  final user = auth.valueOrNull;
  if (user == null || !user.isEmailVerified) {
    if (_publicPaths.contains(location)) return null;
    return location == _splashPath ? '/' : '/login';
  }

  if (!user.termsAccepted) return location == _termsPath ? null : _termsPath;

  if (_guestOnlyPaths.contains(location) || location == _termsPath) {
    final needsSetup = user.monthlyIncomeCents == null || user.monthlyIncomeCents == 0;
    return needsSetup ? '/onboarding' : '/home';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.listen<bool>(sessionExpiredProvider, (_, expired) {
    if (expired) ref.read(authControllerProvider.notifier).handleSessionExpired();
  });

  return GoRouter(
    initialLocation: _splashPath,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: _splashPath,
        builder: (context, state) => const Scaffold(
          body: AmbientGlassBackground(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final extra = state.extra is Map ? state.extra as Map : const {};
          return LoginScreen(
            initialEmail: extra['email'] as String?,
            notice: extra['notice'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final email = state.extra as String?;
          return ResetPasswordScreen(initialEmail: email);
        },
      ),
      GoRoute(
        path: _termsPath,
        builder: (context, state) => const TermsConsentScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const InitialSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Giao dịch (D1 - D4)
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/transactions/detail',
        builder: (context, state) {
          final tx = state.extra as TransactionEntity;
          return TransactionDetailScreen(transaction: tx);
        },
      ),
      GoRoute(
        path: '/transactions/transfer',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/transactions/scan-receipt',
        builder: (context, state) => const ReceiptScannerScreen(),
      ),

      // Kế hoạch (G1 - G11)
      GoRoute(
        path: '/planning',
        builder: (context, state) => const PlanningScreen(),
      ),
      GoRoute(
        path: '/planning/goals/detail',
        builder: (context, state) {
          final goal = state.extra as SavingsGoalEntity;
          return SavingsGoalDetailScreen(goal: goal);
        },
      ),
      GoRoute(
        path: '/planning/recurring',
        builder: (context, state) => const RecurringTransactionsScreen(),
      ),
      GoRoute(
        path: '/planning/loans',
        builder: (context, state) => const LoansScreen(),
      ),

      // Phân tích (F1 - F6)
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/analytics/category-report',
        builder: (context, state) => const CategoryReportScreen(),
      ),
      GoRoute(
        path: '/analytics/forecast',
        builder: (context, state) => const CashflowForecastScreen(),
      ),
      GoRoute(
        path: '/analytics/anomalies',
        builder: (context, state) => const SpendingAnomaliesScreen(),
      ),
      GoRoute(
        path: '/analytics/purchase-check',
        builder: (context, state) => const PurchaseCheckScreen(),
      ),
      GoRoute(
        path: '/analytics/insights',
        builder: (context, state) => const AiInsightsScreen(),
      ),

      // Trợ lý AI (E1 - E3)
      GoRoute(
        path: '/assistant',
        builder: (context, state) => AssistantScreen(startWith: state.uri.queryParameters['start']),
      ),
      GoRoute(
        path: '/assistant/review',
        builder: (context, state) => TransactionReviewScreen(args: state.extra as ReviewArgs),
      ),
      GoRoute(
        path: '/assistant/memory',
        builder: (context, state) => const AiMemoryScreen(),
      ),

      // Hồ sơ & Cài đặt (H1 - H21)
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/appearance',
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),
      GoRoute(
        path: '/profile/backup-export',
        builder: (context, state) => const BackupExportScreen(),
      ),
      GoRoute(
        path: '/profile/accounts',
        builder: (context, state) => const FinancialAccountsScreen(),
      ),
      GoRoute(
        path: '/profile/terms',
        builder: (context, state) => const LegalDocumentScreen(type: LegalDocType.terms),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (context, state) => const LegalDocumentScreen(type: LegalDocType.privacy),
      ),
      GoRoute(
        path: '/profile/consents',
        builder: (context, state) => const ConsentManagementScreen(),
      ),
      GoRoute(
        path: '/profile/categories',
        builder: (context, state) => const CategoryManagementScreen(),
      ),
      GoRoute(
        path: '/profile/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/profile/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/profile/support/ticket',
        builder: (context, state) {
          final ticket = state.extra as SupportTicket;
          return SupportTicketDetailScreen(ticket: ticket);
        },
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/profile/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),

      // Phương pháp tài chính (B3 - B7)
      GoRoute(
        path: '/finance-survey',
        builder: (context, state) => SurveyScreen(onboarding: state.uri.queryParameters['onboarding'] == '1'),
      ),
      GoRoute(
        path: '/finance-recommendation',
        builder: (context, state) => RecommendationScreen(onboarding: state.uri.queryParameters['onboarding'] == '1'),
      ),
      GoRoute(
        path: '/finance-methods',
        builder: (context, state) => const MyMethodsScreen(),
      ),
      GoRoute(
        path: '/finance-methods/detail',
        builder: (context, state) => const MethodDetailScreen(),
      ),
      GoRoute(
        path: '/alert-thresholds',
        builder: (context, state) => const AlertThresholdsScreen(),
      ),

      // QR Transfer (C1 - C5)
      GoRoute(
        path: '/qr-scan',
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/qr-transfer',
        builder: (context, state) => QrTransferScreen(scanned: state.extra is VietQrData ? state.extra as VietQrData : null),
      ),
      GoRoute(
        path: '/qr-history',
        builder: (context, state) => const QrHistoryScreen(),
      ),
      GoRoute(
        path: '/qr/counterparties',
        builder: (context, state) => const SavedCounterpartiesScreen(),
      ),

      // Nhóm & Cộng đồng (I1 - I7, J1 - J6)
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsHubScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityFeedScreen(),
      ),
    ],
  );
});
