import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/terms_consent_screen.dart';
import 'package:finmate/features/auth/presentation/screens/welcome_screen.dart';
import 'package:finmate/features/auth/presentation/screens/login_screen.dart';
import 'package:finmate/features/auth/presentation/screens/register_screen.dart';
import 'package:finmate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:finmate/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:finmate/features/auth/presentation/screens/forgot_password_otp_screen.dart';
import 'package:finmate/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:finmate/features/onboarding/presentation/screens/initial_setup_screen.dart';
import 'package:finmate/features/onboarding/presentation/screens/notification_permission_screen.dart';
import 'package:finmate/features/dashboard/presentation/screens/home_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:finmate/features/planning/presentation/screens/planning_hub_screen.dart';
import 'package:finmate/features/planning/presentation/screens/goals_screen.dart';
import 'package:finmate/features/planning/presentation/screens/goal_form_screen.dart';
import 'package:finmate/features/planning/presentation/screens/budgets_screen.dart';
import 'package:finmate/features/planning/presentation/screens/budget_form_screen.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/screens/recurring_form_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/f2_category_report_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/f4_alerts_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/f6_ai_summary_screen.dart';
import 'package:finmate/features/profile/presentation/screens/profile_screen.dart';
import 'package:finmate/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:finmate/features/survey/presentation/screens/survey_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_create_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_access_log_screen.dart';
import 'package:finmate/features/subscriptions/presentation/screens/subscriptions_screen.dart';

import 'package:finmate/features/community/presentation/screens/community_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_places_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_place_detail_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_profile_screen.dart';
import 'package:finmate/features/categories/presentation/screens/categories_screen.dart';
import 'package:finmate/features/recurring/presentation/screens/recurring_items_screen.dart';
import 'package:finmate/features/groups/presentation/screens/create_bill_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_approvals_screen.dart';
import 'package:finmate/features/groups/presentation/screens/groups_screen.dart';
import 'package:finmate/features/groups/presentation/screens/i2_create_group_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:finmate/features/groups/presentation/screens/i4_members_screen.dart';
import 'package:finmate/features/groups/presentation/screens/i5_invite_members_screen.dart';
import 'package:finmate/features/groups/presentation/screens/i7_group_settings_screen.dart';
import 'package:finmate/features/groups/presentation/screens/accept_invitation_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_finance_screen.dart';
import 'package:finmate/features/forecast/presentation/screens/f3_cashflow_forecast_screen.dart';
import 'package:finmate/features/forecast/presentation/screens/f5_purchase_check_screen.dart';
import 'package:finmate/features/forecast/presentation/screens/forecast_screen.dart';
import 'package:finmate/features/forecast/presentation/screens/forecast_settings_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/ai_memory_screen.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/screens/loans_screen.dart';
import 'package:finmate/features/planning/presentation/screens/recurring_transactions_screen.dart';
import 'package:finmate/features/planning/presentation/screens/savings_goal_detail_screen.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/screens/receipt_scanner_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transaction_detail_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transfer_screen.dart';
import 'package:finmate/features/profile/presentation/screens/appearance_settings_screen.dart';
import 'package:finmate/features/profile/presentation/screens/backup_export_screen.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/profile/presentation/screens/category_form_screen.dart';
import 'package:finmate/features/profile/presentation/screens/category_management_screen.dart';
import 'package:finmate/features/profile/presentation/screens/change_password_screen.dart';
import 'package:finmate/features/profile/presentation/screens/consent_management_screen.dart';
import 'package:finmate/features/profile/presentation/screens/delete_account_screen.dart';
import 'package:finmate/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:finmate/features/profile/presentation/screens/add_financial_account_screen.dart';
import 'package:finmate/features/profile/presentation/screens/financial_accounts_screen.dart';
import 'package:finmate/features/profile/presentation/screens/legal_document_screen.dart';
import 'package:finmate/features/profile/presentation/screens/subscription_screen.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c1_scan_qr_screen.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c2_confirm_transfer_screen.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c3_history_screen.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c4_saved_beneficiaries_screen.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/c5_edit_beneficiary_screen.dart';
import 'package:finmate/features/devices/presentation/screens/devices_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b4_recommendations_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b5_my_methods_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b6_jar_detail_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b7_alert_thresholds_screen.dart';
import 'package:finmate/features/home_widget/data/widget_config_bridge.dart';
import 'package:finmate/features/home_widget/domain/widget_config.dart';
import 'package:finmate/features/home_widget/presentation/screens/k1_widget_config_screen.dart';
import 'package:finmate/features/notifications_inbox/presentation/screens/notifications_inbox_screen.dart';

const _splashPath = '/splash';
const _termsPath = '/terms';

/// Các màn hình không cần đăng nhập
const _publicPaths = {
  '/',
  '/login',
  '/register',
  '/verify-otp',
  '/forgot-password',
  '/forgot-password-otp',
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
  '/forgot-password-otp',
  '/reset-password',
};

/// Hàm điều hướng có điều kiện theo trạng thái đăng nhập (tách riêng để dễ kiểm thử)
String? authRedirect(AsyncValue<UserProfile?> auth, String location) {
  // URI lạ không phải path thật của app (vd. "glance-action://..." lọt vào từ trampoline nội bộ
  // của Jetpack Glance trên Android 16) — về /home thay vì để GoRouter báo "Page Not Found".
  if (!location.startsWith('/')) return '/home';

  // Đang kiểm tra/đăng nhập: giữ nguyên vị trí hiện tại
  if (auth.isLoading) return null;

  final user = auth.valueOrNull;
  if (user == null || !user.isEmailVerified) {
    if (_publicPaths.contains(location)) return null;
    return location == _splashPath ? '/' : '/login';
  }

  // Chưa đồng ý Điều khoản + Chính sách (hoặc chúng đã đổi phiên bản): không vào được chỗ nào khác
  if (!user.termsAccepted) return location == _termsPath ? null : _termsPath;

  if (_guestOnlyPaths.contains(location) || location == _termsPath) {
    final needsSetup = user.monthlyIncomeCents == null || user.monthlyIncomeCents == 0;
    return needsSetup ? '/onboarding' : '/home';
  }
  return null;
}

/// Route mở đầu tiên. Cửa sổ bong bóng FinMate AI (assistant_bubble_main.dart) ghi đè thành '/assistant';
/// đang kiểm tra đăng nhập thì redirect giữ nguyên vị trí, chưa đăng nhập thì vẫn bị đưa về /login.
final initialLocationProvider = Provider<String>((ref) => _splashPath);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  // Đăng nhập/đăng xuất/hết phiên đều làm router đánh giá lại redirect
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.listen<bool>(sessionExpiredProvider, (_, expired) {
    if (expired) ref.read(authControllerProvider.notifier).handleSessionExpired();
  });

  return GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    onException: (context, state, router) => router.go('/home'),
    routes: [
      GoRoute(
        path: _splashPath,
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          // extra chỉ mang dữ liệu trong bộ nhớ (không đưa email lên URL)
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
        path: '/forgot-password-otp',
        builder: (context, state) => ForgotPasswordOtpScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final extra = state.extra is Map ? state.extra as Map : const {};
          return ResetPasswordScreen(
            email: extra['email'] as String? ?? '',
            code: extra['code'] as String? ?? '',
          );
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
        path: '/onboarding/notification-permission',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/planning',
        builder: (context, state) => const PlanningHubScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/analytics/categories',
        builder: (context, state) => const F2CategoryReportScreen(),
      ),
      GoRoute(
        path: '/analytics/alerts',
        builder: (context, state) => const F4AlertsScreen(),
      ),
      GoRoute(
        path: '/analytics/purchase-check',
        builder: (context, state) => const F5PurchaseCheckScreen(),
      ),
      GoRoute(
        path: '/analytics/cashflow',
        builder: (context, state) => const F3CashflowForecastScreen(),
      ),
      GoRoute(
        path: '/analytics/insights',
        builder: (context, state) => const F6AiSummaryScreen(),
      ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) => AssistantScreen(startWith: state.uri.queryParameters['start']),
      ),
      GoRoute(
        path: '/assistant/review',
        builder: (context, state) => TransactionReviewScreen(args: state.extra as ReviewArgs),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/recurring-items',
        builder: (context, state) => const RecurringItemsScreen(),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const I2CreateGroupScreen(),
      ),
      GoRoute(
        path: '/group-detail',
        builder: (context, state) => GroupDetailScreen(groupId: state.extra as String),
      ),
      GoRoute(
        path: '/group-bill-new',
        builder: (context, state) => CreateBillScreen(groupId: state.extra as String),
      ),
      GoRoute(
        path: '/group-approvals',
        builder: (context, state) => GroupApprovalsScreen(groupId: state.extra as String),
      ),
      GoRoute(
        path: '/group-members',
        builder: (context, state) => I4MembersScreen(groupId: state.extra as String),
      ),
      GoRoute(
        path: '/group-invite',
        builder: (context, state) => I5InviteMembersScreen(groupId: state.extra as String),
      ),
      GoRoute(
        path: '/group-settings',
        builder: (context, state) => I7GroupSettingsScreen(groupId: state.extra as String),
      ),
      GoRoute(
        path: '/forecast',
        builder: (context, state) => const ForecastScreen(),
      ),
      GoRoute(
        path: '/forecast-settings',
        builder: (context, state) => const ForecastSettingsScreen(),
      ),
      GoRoute(
        path: '/assistant/memory',
        builder: (context, state) => const AiMemoryScreen(),
      ),
      GoRoute(
        path: '/transaction-detail',
        builder: (context, state) => TransactionDetailScreen(transaction: state.extra as TransactionEntity),
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/scan-receipt',
        builder: (context, state) => const ReceiptScannerScreen(),
      ),
      GoRoute(
        path: '/planning/goal',
        builder: (context, state) => SavingsGoalDetailScreen(goal: state.extra as SavingsGoalEntity),
      ),
      GoRoute(
        path: '/planning/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/planning/goals/form',
        builder: (context, state) => GoalFormScreen(goal: state.extra as SavingsGoalEntity?),
      ),
      GoRoute(
        path: '/planning/budgets',
        builder: (context, state) => const BudgetsScreen(),
      ),
      GoRoute(
        path: '/planning/budgets/form',
        builder: (context, state) => BudgetFormScreen(budget: state.extra as BudgetEntity?),
      ),
      GoRoute(
        path: '/planning/recurring',
        builder: (context, state) => const RecurringTransactionsScreen(),
      ),
      GoRoute(
        path: '/planning/recurring/form',
        builder: (context, state) => RecurringFormScreen(item: state.extra as RecurringItemEntity?),
      ),
      GoRoute(
        path: '/planning/loans',
        builder: (context, state) => const LoansScreen(),
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
        path: '/profile/backup',
        builder: (context, state) => const BackupExportScreen(),
      ),
      GoRoute(
        path: '/profile/financial-accounts',
        builder: (context, state) => const FinancialAccountsScreen(),
      ),
      GoRoute(
        path: '/profile/financial-accounts/add',
        builder: (context, state) => const AddFinancialAccountScreen(),
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
        path: '/profile/categories/form',
        builder: (context, state) => CategoryFormScreen(editing: state.extra as Category?),
      ),
      GoRoute(
        path: '/profile/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/profile/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalDocumentScreen(type: LegalDocType.terms),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalDocumentScreen(type: LegalDocType.privacy),
      ),
      GoRoute(
        path: '/qr-transfers/scan',
        builder: (context, state) => const C1ScanQrScreen(),
      ),
      GoRoute(
        path: '/qr-transfers/confirm',
        builder: (context, state) {
          final extra = state.extra is Map ? state.extra as Map : const {};
          return C2ConfirmTransferScreen(
            initialReceiverBankBin: extra['receiverBankBin'] as String?,
            initialAccountNumber: extra['receiverAccountNumber'] as String?,
            initialReceiverName: extra['receiverName'] as String?,
            initialAmountCents: extra['amountCents'] as BigInt?,
            initialMessage: extra['message'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/qr-transfers/history',
        builder: (context, state) => const C3HistoryScreen(),
      ),
      GoRoute(
        path: '/qr-transfers/beneficiaries',
        builder: (context, state) => const C4SavedBeneficiariesScreen(),
      ),
      GoRoute(
        path: '/qr-transfers/beneficiaries/edit',
        builder: (context, state) => C5EditBeneficiaryScreen(counterparty: state.extra as CounterpartyOverrideEntity),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/finance-methods',
        builder: (context, state) => const RecommendationsScreen(),
      ),
      GoRoute(
        path: '/finance-methods/my-methods',
        builder: (context, state) => const MyMethodsScreen(),
      ),
      GoRoute(
        path: '/finance-methods/alert-thresholds',
        builder: (context, state) => const AlertThresholdsScreen(),
      ),
      GoRoute(
        path: '/finance-methods/jar-detail',
        builder: (context, state) {
          final extra = state.extra as Map;
          return JarDetailScreen(
            userMethodId: extra['userMethodId'] as String,
            jarKey: extra['jarKey'] as String,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsInboxScreen(),
      ),
      GoRoute(
        path: '/survey',
        builder: (context, state) => const SurveyScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/support/new',
        builder: (context, state) => const SupportCreateScreen(),
      ),
      GoRoute(
        path: '/support-ticket',
        builder: (context, state) => SupportTicketDetailScreen(ticketId: state.extra as String),
      ),
      GoRoute(
        path: '/support-access-log',
        builder: (context, state) => const SupportAccessLogScreen(),
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/community-post',
        builder: (context, state) => CommunityPostDetailScreen(postId: state.extra as String),
      ),
      GoRoute(
        path: '/community-places',
        builder: (context, state) => const CommunityPlacesScreen(),
      ),
      GoRoute(
        path: '/community-place',
        builder: (context, state) => CommunityPlaceDetailScreen(placeId: state.extra as String),
      ),
      GoRoute(
        path: '/community-profile',
        builder: (context, state) => const CommunityProfileScreen(),
      ),
      GoRoute(
        path: '/accept-invitation',
        builder: (context, state) => AcceptInvitationScreen(initialToken: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(
        path: '/group-finance',
        builder: (context, state) => GroupFinanceScreen(groupId: state.extra as String),
      ),
      GoRoute(
        // Mở lại y hệt K1WidgetConfigScreen (dùng chung với lối vào native WidgetConfigActivity lúc
        // ghim lần đầu) nhưng ở chế độ sửa — không có appWidgetId cụ thể nên áp dụng cho TẤT CẢ
        // widget đang ghim của loại truyền qua ?kind= (xem editAllPinned).
        path: '/widget-settings',
        builder: (context, state) {
          final kindId = state.uri.queryParameters['kind'];
          return K1WidgetConfigScreen(
            bridge: WidgetConfigBridge(),
            initialKind: kindId != null ? HomeWidgetKind.fromId(kindId) : null,
            editAllPinned: true,
          );
        },
      ),
    ],
  );
});
