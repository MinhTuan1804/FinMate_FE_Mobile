import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/devices/data/devices_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('DevicesRepository', () {
    test('registerDevice POST đúng path và body', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = DevicesRepository(apiClient: testApiClient(adapter));

      await repo.registerDevice(token: 'tok-123', platform: 'Android');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/devices'));
      expect(req.data, {'token': 'tok-123', 'platform': 'Android'});
    });

    test('unregisterDevice DELETE đúng path và body (token trong body, không trên URL)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = DevicesRepository(apiClient: testApiClient(adapter));

      await repo.unregisterDevice('tok-123');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, contains('/api/v1/devices'));
      expect(req.data, {'token': 'tok-123'});
    });
  });
}
