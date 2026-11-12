import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/terms_consent_screen.dart';
import 'package:finmate/features/auth/presentation/screens/ai_consent_screen.dart';
import 'package:finmate/features/auth/presentation/screens/welcome_screen.dart';
import 'package:finmate/features/auth/presentation/screens/login_screen.dart';
import 'package:finmate/features/auth/presentation/screens/register_screen.dart';
import 'package:finmate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:finmate/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:finmate/features/auth/presentation/screens/forgot_password_otp_screen.dart';
import 'package:finmate/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:finmate/features/onboarding/presentation/screens/initial_setup_screen.dart';
import 'package:finmate/features/dashboard/presentation/screens/home_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:finmate/features/planning/presentation/screens/planning_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:finmate/features/profile/presentation/screens/profile_screen.dart';
import 'package:finmate/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:finmate/features/survey/presentation/screens/survey_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:finmate/features/support/presentation/screens/support_access_log_screen.dart';
import 'package:finmate/features/app_config/presentation/screens/app_config_screen.dart';
import 'package:finmate/features/subscriptions/presentation/screens/subscriptions_screen.dart';

import 'package:finmate/features/community/presentation/screens/community_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_places_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_place_detail_screen.dart';
import 'package:finmate/features/community/presentation/screens/community_profile_screen.dart';
import 'package:finmate/features/categories/presentation/screens/categories_screen.dart';
import 'package:finmate/features/recurring/presentation/screens/recurring_items_screen.dart';
import 'package:finmate/features/groups/presentation/screens/groups_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:finmate/features/groups/presentation/screens/accept_invitation_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_finance_screen.dart';
import 'package:finmate/features/forecast/presentation/screens/forecast_screen.dart';
import 'package:finmate/features/forecast/presentation/screens/forecast_settings_screen.dart';
import 'package:finmate/features/qr_transfers/presentation/screens/qr_transfer_screen.dart';
import 'package:finmate/features/devices/presentation/screens/devices_screen.dart';
import 'package:finmate/features/finance_methods/presentation/screens/finance_methods_screen.dart';

const _splashPath = '/splash';
const _termsPath = '/terms';
const _aiConsentPath = '/ai-consent';

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
  // Đang kiểm tra/đăng nhập: giữ nguyên vị trí hiện tại
  if (auth.isLoading) return null;

  final user = auth.valueOrNull;
  if (user == null || !user.isEmailVerified) {
    if (_publicPaths.contains(location)) return null;
    return location == _splashPath ? '/' : '/login';
  }

  // Chưa đồng ý Điều khoản + Chính sách (hoặc chúng đã đổi phiên bản): không vào được chỗ nào khác
  if (!user.termsAccepted) return location == _termsPath ? null : _termsPath;

  // Vừa đồng ý Điều khoản: để màn /ai-consent tự điều hướng tiếp, không ép đi trước khi hiện xong
  if (location == _aiConsentPath) return null;

  if (_guestOnlyPaths.contains(location) || location == _termsPath) {
    final needsSetup = user.monthlyIncomeCents == null || user.monthlyIncomeCents == 0;
    return needsSetup ? '/onboarding' : '/home';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  // Đăng nhập/đăng xuất/hết phiên đều làm router đánh giá lại redirect
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
        path: _aiConsentPath,
        builder: (context, state) => const AiConsentScreen(),
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
        path: '/transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/planning',
        builder: (context, state) => const PlanningScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
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
        path: '/group-detail',
        builder: (context, state) => GroupDetailScreen(groupId: state.extra as String),
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
        path: '/qr-transfers',
        builder: (context, state) => const QrTransferScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/finance-methods',
        builder: (context, state) => const FinanceMethodsScreen(),
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
        path: '/support-ticket',
        builder: (context, state) => SupportTicketDetailScreen(ticketId: state.extra as String),
      ),
      GoRoute(
        path: '/support-access-log',
        builder: (context, state) => const SupportAccessLogScreen(),
      ),
      GoRoute(
        path: '/app-config',
        builder: (context, state) => const AppConfigScreen(),
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
        builder: (context, state) => const AcceptInvitationScreen(),
      ),
      GoRoute(
        path: '/group-finance',
        builder: (context, state) => GroupFinanceScreen(groupId: state.extra as String),
      ),
    ],
  );
});
