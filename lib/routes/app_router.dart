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
import 'package:finmate/features/onboarding/presentation/screens/initial_setup_screen.dart';
import 'package:finmate/features/dashboard/presentation/screens/home_screen.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:finmate/features/planning/presentation/screens/planning_screen.dart';
import 'package:finmate/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:finmate/features/profile/presentation/screens/profile_screen.dart';

const _splashPath = '/splash';
const _termsPath = '/terms';

/// Các màn hình không cần đăng nhập
const _publicPaths = {'/', '/login', '/register', '/verify-otp'};

/// Các màn hình dành cho khách: người dùng đã đăng nhập sẽ được chuyển đi chỗ khác
const _guestOnlyPaths = {_splashPath, '/', '/login', '/register', '/verify-otp'};

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
    ],
  );
});
