import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/data/auth_repository.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';

UserProfile consentTestUser({bool terms = false, bool ai = false, bool training = false}) => UserProfile(
      id: 'u1',
      email: 'probe@example.com',
      displayName: 'Probe',
      isEmailVerified: true,
      notificationPrefs: NotificationPrefs.defaultPrefs(),
      createdAt: DateTime(2026),
      termsAccepted: terms,
      aiConsentGranted: ai,
      trainingConsentGranted: training,
    );

/// Repository giả cho các màn đồng ý: ghi lại lời gọi, [failNext] làm lần kế tiếp lỗi
class ConsentRepo implements IAuthRepository {
  UserProfile user;
  final List<String> calls = [];
  bool failNext = false;

  ConsentRepo(this.user);

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw ApiException(message: 'Không lưu được, thử lại nhé', statusCode: 500);
    }
  }

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<UserProfile> getMe() async => user;

  @override
  Future<UserProfile> acceptConsent(ConsentKind kind) async {
    calls.add('accept:${kind.name}');
    _maybeFail();
    return user = user.copyWith(
      termsAccepted: kind == ConsentKind.terms ? true : null,
      // Như server: điều khoản đã nêu việc gửi tên món cho AI nên đồng ý điều khoản cũng bật AI
      aiConsentGranted: kind == ConsentKind.ai || kind == ConsentKind.terms ? true : null,
      trainingConsentGranted: kind == ConsentKind.training ? true : null,
    );
  }

  @override
  Future<UserProfile> withdrawConsent(ConsentKind kind) async {
    calls.add('withdraw:${kind.name}');
    _maybeFail();
    return user = user.copyWith(
      aiConsentGranted: kind == ConsentKind.ai ? false : null,
      trainingConsentGranted: kind == ConsentKind.training ? false : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
