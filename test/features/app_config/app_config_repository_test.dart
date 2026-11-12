import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/app_config/data/app_config_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('AppConfigRepository.getConfig', () {
    test('gọi đúng GET /api/v1/app-config, không cần token', () async {
      final adapter = RouteAdapter((o) => respondFixture('app_config'));
      final repo = AppConfigRepository(apiClient: testApiClient(adapter));

      final config = await repo.getConfig();

      final req = adapter.to('/api/v1/app-config').single;
      expect(req.method, 'GET');
      // Không có khóa Authorization: AppConfigController [AllowAnonymous], TokenStorage trống cũng gọi được.
      expect(req.headers.containsKey('Authorization'), isFalse);

      expect(config.version, 3);
      expect(config.maintenance.enabled, isFalse);
      expect(config.appVersion.latestVersion, '1.2.0');
      expect(config.appVersion.forceUpdate, isFalse);
      expect(config.features.chatAi, isTrue);
      expect(config.features.groups, isFalse);
      expect(config.features.support, isTrue);
      expect(config.theme.primaryColor, '#1E88E5');
      expect(config.theme.textScale, 1.0);
      // Các nhóm không map riêng (limits/sync/qrTransfer/...) vẫn còn nguyên trong raw để debug.
      expect(config.raw['limits'], isNotNull);
      expect(config.raw['qrTransfer'], isNotNull);
    });

    test('bảo trì bật: đọc đủ title/message/estimatedEndAt, forceUpdate true', () async {
      final adapter = RouteAdapter((o) => respondFixture('app_config_maintenance'));
      final repo = AppConfigRepository(apiClient: testApiClient(adapter));

      final config = await repo.getConfig();

      expect(config.maintenance.enabled, isTrue);
      expect(config.maintenance.title, 'Đang bảo trì');
      expect(config.maintenance.estimatedEndAt, isNotNull);
      expect(config.appVersion.forceUpdate, isTrue);
    });
  });
}
