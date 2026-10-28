import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/auth/data/auth_repository.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import '../../fixtures/fixture.dart';

void main() {
  test('UserProfile.fromJson đọc đúng response thật của users/me', () {
    final user = UserProfile.fromJson(fixtureData('users_me') as Map<String, dynamic>);

    expect(user.email, 'fm-probe-1790715474@example.com');
    expect(user.displayName, 'Probe');
    expect(user.isEmailVerified, isTrue);
    expect(user.monthlyIncomeCents, isNull);
    expect(user.notificationPrefs.pushEnabled, isTrue);
    expect(user.notificationPrefs.budgetAlertsEnabled, isTrue);
  });

  test('UserProfile.fromJson đọc cờ thông báo phẳng khi bị tắt', () {
    final json = Map<String, dynamic>.from(fixtureData('users_me') as Map)
      ..['pushEnabled'] = false
      ..['monthlyIncomeCents'] = 15000000;
    final user = UserProfile.fromJson(json);

    expect(user.notificationPrefs.pushEnabled, isFalse);
    expect(user.monthlyIncomeCents, 15000000);
  });

  test('AuthRepository.login lưu token rồi lấy hồ sơ từ users/me (login không trả user)', () async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/auth/login')) return respondFixture('login');
      if (o.path.contains('/users/me')) return respondFixture('users_me');
      return respondJson({'success': false}, status: 404);
    });
    final storage = InMemoryTokenStorage();
    final client = ApiClient(
      tokenStorage: storage,
      customDio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );
    final repo = AuthRepository(apiClient: client, tokenStorage: storage);

    final user = await repo.login(email: 'a@b.com', password: 'x');

    expect(user.email, 'fm-probe-1790715474@example.com');
    expect(await storage.getAccessToken(), 'access-token');
    expect(await storage.getRefreshToken(), 'refresh-token');
    // users/me phải mang token vừa lưu
    expect(adapter.to('/users/me').single.headers['Authorization'], 'Bearer access-token');
  });

  test('đồng ý: hồ sơ mặc định chưa đồng ý gì; đọc termsAccepted và aiConsentGranted từ server', () {
    final fresh = UserProfile.fromJson(fixtureData('users_me') as Map<String, dynamic>);
    expect((fresh.termsAccepted, fresh.aiConsentGranted, fresh.trainingConsentGranted), (false, false, false));

    final json = Map<String, dynamic>.from(fixtureData('users_me') as Map)
      ..['termsAccepted'] = true
      ..['aiConsentGranted'] = true
      ..['trainingConsentGranted'] = true;
    final agreed = UserProfile.fromJson(json);
    expect((agreed.termsAccepted, agreed.aiConsentGranted, agreed.trainingConsentGranted), (true, true, true));
  });

  AuthRepository repoWith(RouteAdapter adapter) {
    final storage = InMemoryTokenStorage();
    return AuthRepository(
      apiClient: ApiClient(tokenStorage: storage, customDio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter),
      tokenStorage: storage,
    );
  }

  test('acceptConsent gửi loại và đúng phiên bản câu chữ app đang hiển thị, trả hồ sơ mới', () async {
    final body = Map<String, dynamic>.from(fixtureData('users_me') as Map)..['aiConsentGranted'] = true;
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': body}));
    final repo = repoWith(adapter);

    final ai = await repo.acceptConsent(ConsentKind.ai);
    await repo.acceptConsent(ConsentKind.terms);

    expect(ai.aiConsentGranted, isTrue);
    final sent = adapter.to('/users/me/consents');
    expect(sent.map((r) => r.method), ['POST', 'POST']);
    expect(sent.first.data, {'kind': 'ai', 'version': ConsentVersions.ai});
    expect(ConsentVersions.ai, 3); // bản 2 thêm OpenRouter, bản 3 thêm chat và giọng nói: người đã đồng ý bản cũ phải đồng ý lại
    expect(sent.last.data, {'kind': 'terms', 'version': ConsentVersions.terms});
  });

  test('acceptConsent(training) gửi loại training và đúng phiên bản câu chữ', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': fixtureData('users_me')}));

    await repoWith(adapter).acceptConsent(ConsentKind.training);

    expect(adapter.to('/users/me/consents').single.data, {'kind': 'training', 'version': ConsentVersions.training});
  });

  test('withdrawConsent(training) gọi DELETE /users/me/consents/training', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': fixtureData('users_me')}));

    await repoWith(adapter).withdrawConsent(ConsentKind.training);

    final request = adapter.to('/users/me/consents/training').single;
    expect(request.method, 'DELETE');
  });

  test('withdrawConsent(ai) gọi DELETE /users/me/consents/ai và trả hồ sơ mới', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': fixtureData('users_me')}));
    final repo = repoWith(adapter);

    final user = await repo.withdrawConsent(ConsentKind.ai);

    expect(user.aiConsentGranted, isFalse);
    final request = adapter.to('/users/me/consents/ai').single;
    expect(request.method, 'DELETE');
  });

  test('updateProfile chỉ gửi tên và thu nhập, không còn đường nào đổi đồng ý qua PATCH', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': fixtureData('users_me')}));
    final repo = repoWith(adapter);

    await repo.updateProfile(displayName: 'Probe', monthlyIncomeCents: 1);

    final body = adapter.to('/users/me').single.data as Map;
    expect(body.keys, unorderedEquals(['displayName', 'monthlyIncomeCents']));
  });
}
