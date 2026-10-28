import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';

abstract class IAuthRepository {
  Future<UserProfile> login({required String email, required String password});
  Future<void> register({required String email, required String password, required String displayName});

  /// Trả về true nếu server cấp token khi xác thực thành công (đã lưu vào TokenStorage)
  Future<bool> verifyEmail({required String email, required String code});
  Future<void> resendVerification({required String email});
  Future<UserProfile> googleLogin({required String idToken});
  Future<UserProfile> getMe();
  /// PATCH /users/me; [monthlyIncomeCents] null nghĩa là giữ nguyên
  Future<UserProfile> updateProfile({required String displayName, int? monthlyIncomeCents});

  /// POST /users/me/consents: ghi đồng ý với đúng phiên bản câu chữ app đang hiển thị (server 409 nếu đã khác)
  Future<UserProfile> acceptConsent(ConsentKind kind);

  /// DELETE /users/me/consents/{kind}: rút lại đồng ý AI hoặc đồng ý đóng góp dữ liệu (rút đóng góp thì server xóa dữ liệu đã đóng góp)
  Future<UserProfile> withdrawConsent(ConsentKind kind);
  Future<void> updateNotificationPrefs(NotificationPrefs prefs);
  Future<void> logout();
  Future<bool> isAuthenticated();
}

class AuthRepository implements IAuthRepository {
  final ApiClient apiClient;
  final ITokenStorage tokenStorage;

  AuthRepository({
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  Future<UserProfile> login({required String email, required String password}) async {
    final response = await apiClient.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
      fromJsonT: (json) => json as Map<String, dynamic>,
    );

    return _saveTokensAndLoadProfile(response.data!);
  }

  /// Backend chỉ trả token khi đăng nhập; hồ sơ lấy riêng từ users/me
  Future<UserProfile> _saveTokensAndLoadProfile(Map<String, dynamic> data) async {
    await tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return getMe();
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await apiClient.post(
      '/api/v1/auth/register',
      data: {'email': email, 'password': password, 'displayName': displayName},
      fromJsonT: (json) => json,
    );
  }

  @override
  Future<bool> verifyEmail({required String email, required String code}) async {
    final response = await apiClient.post(
      '/api/v1/auth/verify-email',
      data: {'email': email, 'code': code},
      fromJsonT: (json) => json,
    );

    // Swagger không mô tả response: nếu server trả token thì đăng nhập luôn
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];
      if (accessToken is String && accessToken.isNotEmpty && refreshToken is String && refreshToken.isNotEmpty) {
        await tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await apiClient.post(
      '/api/v1/auth/resend-verification',
      data: {'email': email},
      fromJsonT: (json) => json,
    );
  }

  @override
  Future<UserProfile> googleLogin({required String idToken}) async {
    final response = await apiClient.post(
      '/api/v1/auth/google',
      data: {'idToken': idToken},
      fromJsonT: (json) => json as Map<String, dynamic>,
    );

    return _saveTokensAndLoadProfile(response.data!);
  }

  @override
  Future<UserProfile> getMe() async {
    final response = await apiClient.get(
      '/api/v1/users/me',
      fromJsonT: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<UserProfile> updateProfile({required String displayName, int? monthlyIncomeCents}) async {
    final response = await apiClient.patch(
      '/api/v1/users/me',
      data: {'displayName': displayName, 'monthlyIncomeCents': monthlyIncomeCents},
      fromJsonT: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<UserProfile> acceptConsent(ConsentKind kind) async {
    final response = await apiClient.post(
      '/api/v1/users/me/consents',
      data: {'kind': kind.name, 'version': ConsentVersions.of(kind)},
      fromJsonT: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<UserProfile> withdrawConsent(ConsentKind kind) async {
    await apiClient.delete('/api/v1/users/me/consents/${kind.name}');
    return getMe(); // ApiClient.delete không đọc phần thân; rút lại đồng ý hiếm nên thêm một lượt gọi là chấp nhận được
  }

  @override
  Future<void> updateNotificationPrefs(NotificationPrefs prefs) async {
    await apiClient.patch(
      '/api/v1/users/me/notification-prefs',
      data: prefs.toJson(),
      fromJsonT: (json) => json,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await apiClient.post(
          '/api/v1/auth/logout',
          data: {'refreshToken': refreshToken},
          fromJsonT: (json) => json,
        );
      } catch (_) {
        // Tiếp tục xóa token cục bộ kể cả khi server trả lỗi
      }
    }
    await tokenStorage.clearTokens();
  }

  @override
  Future<bool> isAuthenticated() => tokenStorage.hasAccessToken();
}
