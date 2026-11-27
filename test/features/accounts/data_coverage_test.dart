import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/data/data_coverage_repository.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';
import '../../fixtures/fixture.dart';

/// Ví dụ lấy đúng từ docs/listener-health-api.md của BE (GET /me/data-coverage).
const _json = {
  'windowDays': 30,
  'coveragePercent': 50,
  'level': 'poor',
  'accounts': [
    {
      'accountId': 'a1',
      'accountName': 'VCB',
      'status': 'silent',
      'lastNotificationAt': '2026-11-11T03:00:00Z',
      'silentDays': 3,
      'daysWithNotifications': 27,
      'notificationsOff': false,
    },
  ],
  'devices': [
    {
      'installationId': 'i1',
      'status': 'ok',
      'permissionGranted': true,
      'listenerConnected': true,
      'lastReportedAt': '2026-11-14T01:00:00Z',
      'appVersion': '2.4.0',
      'manufacturer': 'xiaomi',
    },
  ],
};

void main() {
  test('DataCoverage.fromJson đọc phần trăm, mức, ví và thiết bị', () {
    final c = DataCoverage.fromJson(_json);

    expect(c.coveragePercent, 50);
    expect(c.level, CoverageLevel.poor);
    expect(c.forAccount('a1')!.status, AccountCoverageStatus.silent);
    expect(c.forAccount('a1')!.silentDays, 3);
    expect(c.forAccount('zzz'), isNull);
    expect(c.devices.single.status, DeviceCoverageStatus.ok);
    expect(c.hasPermissionLost, isFalse);
  });

  test('giá trị lạ không ném: mức/trạng thái thành unknown, thiếu % thì null', () {
    final c = DataCoverage.fromJson({
      'level': 'whatever',
      'accounts': [
        {'accountId': 'a', 'status': 'new_status_from_future'},
      ],
      'devices': [
        {'installationId': 'd', 'status': 'permission_lost'},
      ],
    });

    expect(c.level, CoverageLevel.unknown);
    expect(c.coveragePercent, isNull);
    expect(c.accounts.single.status, AccountCoverageStatus.unknown);
    expect(c.hasPermissionLost, isTrue);
  });

  test('getCoverage gọi GET /me/data-coverage?days=', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': _json}));
    final repo = DataCoverageRepository(apiClient: testApiClient(adapter));

    final c = await repo.getCoverage(days: 14);

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/api/v1/me/data-coverage');
    expect(adapter.requests.single.queryParameters, {'days': 14});
    expect(c.level, CoverageLevel.poor);
  });
}
