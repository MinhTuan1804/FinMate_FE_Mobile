import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/network/native_token_storage.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/auth/data/auth_repository.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';

// Providers
final tokenStorageProvider = Provider<ITokenStorage>((ref) => !kIsWeb && Platform.isAndroid
    ? NativeTokenStorage(
        bridge: sharedNotificationBridge,
        legacy: SecureTokenStorage(),
        baseUrl: ApiClient.defaultBaseUrl,
      )
    : SecureTokenStorage());

final sessionExpiredProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: () {
      ref.read(sessionExpiredProvider.notifier).state = true;
    },
  );
});

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
});

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(
    repository: repository,
  );
});

/// Id người dùng hiện tại; các provider dữ liệu `watch` để tự tạo lại khi đổi/đăng xuất
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((s) => s.valueOrNull?.id)),
);

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final IAuthRepository repository;

  /// Dọn dữ liệu cục bộ khi kết thúc phiên (đăng xuất hoặc hết hạn)
  final Future<void> Function()? onSignedOut;

  AuthController({required this.repository, this.onSignedOut})
      : super(const AsyncValue.loading()) {
    checkAuthStatus();
  }

  Future<void> _signOutLocally() async {
    try {
      await onSignedOut?.call();
    } catch (_) {
      // Không để lỗi dọn dẹp chặn việc đăng xuất
    }
    state = const AsyncValue.data(null);
  }

  Future<void> checkAuthStatus() async {
    state = const AsyncValue.loading();
    try {
      final isAuth = await repository.isAuthenticated();
      if (!isAuth) {
        state = const AsyncValue.data(null);
        return;
      }
      final user = await repository.getMe();
      state = AsyncValue.data(user);
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.login(email: email, password: password));
  }

  /// Đăng ký không đụng tới trạng thái đăng nhập; lỗi được ném lại cho màn hình xử lý.
  Future<void> register(String email, String password, String displayName) {
    return repository.register(email: email, password: password, displayName: displayName);
  }

  /// Xác thực OTP. Trả về true nếu sau đó người dùng đã đăng nhập (có token hợp lệ),
  /// false nếu cần đăng nhập lại. Lỗi được ném lại cho màn hình xử lý.
  Future<bool> verifyEmail(String email, String code) async {
    final gotTokens = await repository.verifyEmail(email: email, code: code);
    if (gotTokens || await repository.isAuthenticated()) {
      await checkAuthStatus();
      return state.valueOrNull != null;
    }
    return false;
  }

  Future<void> resendVerification(String email) async {
    await repository.resendVerification(email: email);
  }

  Future<void> googleLogin(String idToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.googleLogin(idToken: idToken));
  }

  Future<void> updateMonthlyIncome(int incomeCents) async {
    final currentUser = state.value;
    if (currentUser == null) {
      throw ApiException(message: 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.', code: 'UNAUTHORIZED');
    }

    // Lỗi được ném lại và không đổi state (đặt state = error sẽ bị coi là đã đăng xuất)
    final updated = await repository.updateProfile(
      displayName: currentUser.displayName,
      monthlyIncomeCents: incomeCents,
    );
    state = AsyncValue.data(updated);
  }

  /// Ghi đồng ý rồi cập nhật hồ sơ. Lỗi được ném lại cho màn hình (đặt state = error sẽ bị coi là đã đăng xuất).
  Future<void> acceptConsent(ConsentKind kind) async {
    _requireUser();
    final updated = await repository.acceptConsent(kind);
    if (mounted) state = AsyncValue.data(updated);
  }

  /// Rút lại đồng ý AI hoặc đóng góp dữ liệu: chỉ đổi giao diện sau khi server đã xác nhận, để không giả vờ đã rút khi chưa
  Future<void> withdrawConsent(ConsentKind kind) async {
    _requireUser();
    final updated = await repository.withdrawConsent(kind);
    if (mounted) state = AsyncValue.data(updated);
  }

  UserProfile _requireUser() =>
      state.value ?? (throw ApiException(message: 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.', code: 'UNAUTHORIZED'));

  Future<void> logout() async {
    await repository.logout();
    await _signOutLocally();
  }

  Future<void> handleSessionExpired() => _signOutLocally();
}
