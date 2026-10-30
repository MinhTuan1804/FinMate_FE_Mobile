import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/config/app_config_repository.dart';
import 'package:finmate/core/config/app_version.dart';
import 'package:finmate/core/theme/app_theme.dart';

class _FakeRepository implements AppConfigRepository {
  _FakeRepository({this.cachedConfig, this.fetched, this.fetchFails = false});

  final AppConfig? cachedConfig;
  AppConfig? fetched;
  bool fetchFails;
  int fetches = 0;

  @override
  Future<AppConfig?> cached() async => cachedConfig;

  @override
  Future<AppConfig> fetch() async {
    fetches++;
    if (fetchFails) throw StateError('mất mạng');
    return fetched!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AppConfig _config(int version, {bool maintenance = false}) => AppConfig(version: version, maintenance: MaintenanceConfig(enabled: maintenance));

ProviderContainer _container(_FakeRepository repository) {
  final container = ProviderContainer(overrides: [
    appConfigRepositoryProvider.overrideWithValue(repository),
    appConfigPollIntervalProvider.overrideWithValue(Duration.zero),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AppConfig.fromJson', () {
    test('đọc đủ các phần của phản hồi', () {
      final config = AppConfig.fromJson({
        'version': 7,
        'config': {
          'maintenance': {'enabled': true, 'title': 'Bảo trì', 'message': 'Quay lại sau 10 phút', 'estimatedEndAt': '2026-10-30T09:00:00+00:00'},
          'appVersion': {'minVersion': '1.2.0', 'latestVersion': '1.4.0', 'forceUpdate': true, 'storeUrl': 'https://play.google.com/store/apps/details?id=x'},
          'features': {'chatAi': false, 'voice': true},
          'theme': {'primaryColor': '#2E7D6B', 'backgroundColor': '#0B0F19', 'navBarColor': '#112233', 'fontFamily': 'Be Vietnam Pro', 'textScale': 1.2, 'logoUrl': 'https://cdn.example.com/logo.png'},
        },
      });

      expect(config.version, 7);
      expect(config.maintenance.enabled, isTrue);
      expect(config.maintenance.estimatedEndAt!.toUtc(), DateTime.utc(2026, 10, 30, 9));
      expect(config.appVersion.forceUpdate, isTrue);
      expect(config.features.chatAi, isFalse);
      expect(config.features.billScan, isTrue);  // thiếu trường nghĩa là còn bật
      expect(config.theme.primaryColor, const Color(0xFF2E7D6B));
      expect(config.theme.fontFamily, 'Be Vietnam Pro');
      expect(config.theme.textScale, 1.2);
      expect(config.theme.logoUrl, 'https://cdn.example.com/logo.png');
    });

    test('rỗng hoặc sai kiểu thì dùng mặc định, không ném lỗi', () {
      for (final broken in <Map<String, dynamic>>[
        {},
        {'version': 'x', 'config': 5},
        {'config': {'maintenance': 'sai', 'theme': [], 'appVersion': null}},
      ]) {
        final config = AppConfig.fromJson(broken);
        expect(config.maintenance.enabled, isFalse);
        expect(config.appVersion.forceUpdate, isFalse);
        expect(config.theme.primaryColor, isNull);
        expect(config.theme.textScale, 1.0);
      }
    });

    test('màu sai, cỡ chữ ngoài khoảng và logo không phải https bị loại', () {
      final theme = ThemeConfig.fromJson({'primaryColor': 'red', 'backgroundColor': '#FFF', 'textScale': 9, 'logoUrl': 'http://cdn.example.com/logo.png'});

      expect(theme.primaryColor, isNull);
      expect(theme.backgroundColor, isNull);
      expect(theme.textScale, ThemeConfig.maxTextScale);
      expect(theme.logoUrl, isNull);
      expect(ThemeConfig.fromJson({'textScale': 0.1}).textScale, ThemeConfig.minTextScale);
    });
  });

  group('QrTransferConfig.fromJson', () {
    test('đọc giá trị admin đặt', () {
      final qr = QrTransferConfig.fromJson({
        'maxAmount': 5000000,
        'maxMessageLength': 50,
        'defaultMessage': 'Chuyen khoan',
        'deeplinkHost': 'pay.example.com',
        'deeplinkReturnUrl': 'https://example.com/back',
      });

      expect((qr.maxAmount, qr.maxMessageLength, qr.defaultMessage), (5000000, 50, 'Chuyen khoan'));
      expect((qr.deeplinkHost, qr.deeplinkReturnUrl), ('pay.example.com', 'https://example.com/back'));
    });

    test('thiếu hoặc sai thì dùng mặc định; máy chủ lạ và liên kết không https bị bỏ', () {
      const defaults = QrTransferConfig();
      for (final broken in <Map<String, dynamic>>[
        {},
        {'deeplinkHost': 'https://evil.example.com', 'deeplinkReturnUrl': 'http://x.test', 'maxAmount': -1, 'maxMessageLength': 5000},
        {'deeplinkHost': '192.168.1.10'},
        {'deeplinkHost': 'dl.vietqr.io/pay'},
        {'deeplinkHost': 'host:8443'},
      ]) {
        final qr = QrTransferConfig.fromJson(broken);

        expect(qr.deeplinkHost, defaults.deeplinkHost);
        expect(qr.deeplinkReturnUrl, defaults.deeplinkReturnUrl);
        expect(qr.maxAmount, defaults.maxAmount);
        expect(qr.maxMessageLength, defaults.maxMessageLength);
      }
    });

    test('AppConfig.fromJson mang theo nhóm qrTransfer', () {
      final config = AppConfig.fromJson({'version': 3, 'config': {'qrTransfer': {'defaultMessage': 'Chuyen khoan'}}});

      expect(config.qrTransfer.defaultMessage, 'Chuyen khoan');
    });
  });

  group('isOlderVersion', () {
    test('so từng số theo thứ tự, không so theo chữ', () {
      expect(isOlderVersion('1.9.0', '1.10.0'), isTrue);
      expect(isOlderVersion('1.10.0', '1.9.0'), isFalse);
      expect(isOlderVersion('1.0.0', '1.0.0'), isFalse);
      expect(isOlderVersion('0.9.9', '1.0.0'), isTrue);
    });

    test('phiên bản không đọc được thì KHÔNG khóa ai', () {
      expect(isOlderVersion('1.0', '2.0.0'), isFalse);
      expect(isOlderVersion('1.0.0', 'x.y.z'), isFalse);
      expect(isOlderVersion('', ''), isFalse);
    });

    test('kAppVersion khớp version trong pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec)!;
      expect(kAppVersion, match.group(1));
    });
  });

  group('AppConfigController', () {
    test('bắt đầu bằng bản đệm rồi thay bằng bản tải về', () async {
      final repository = _FakeRepository(cachedConfig: _config(3), fetched: _config(5, maintenance: true));
      final container = _container(repository);

      expect(container.read(appConfigProvider).version, 0);  // chưa có gì thì là mặc định
      await pumpEventQueue();

      expect(container.read(appConfigProvider).version, 5);
      expect(container.read(appConfigProvider).maintenance.enabled, isTrue);
    });

    test('mất mạng thì giữ bản đệm, không tự bật bảo trì', () async {
      final repository = _FakeRepository(cachedConfig: _config(3), fetchFails: true);
      final container = _container(repository);

      container.read(appConfigProvider);
      await pumpEventQueue();

      expect(container.read(appConfigProvider).version, 3);
      expect(container.read(appConfigProvider).maintenance.enabled, isFalse);
    });

    test('cùng số phiên bản thì không thay: app không dựng lại mỗi lần hỏi', () async {
      final repository = _FakeRepository(fetched: _config(4));
      final container = _container(repository);
      container.read(appConfigProvider);
      await pumpEventQueue();
      final first = container.read(appConfigProvider);

      repository.fetched = _config(4, maintenance: true);  // cùng version: coi như không đổi
      await container.read(appConfigProvider.notifier).refresh();

      expect(identical(container.read(appConfigProvider), first), isTrue);
    });
  });

  group('AppTheme.applyConfig', () {
    setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

    test('đổi màu chủ đạo, nền và thanh điều hướng của theme', () {
      final themed = AppTheme.applyConfig(
        AppTheme.darkTheme,
        const ThemeConfig(primaryColor: Color(0xFFFFD54F), backgroundColor: Color(0xFF101010), navBarColor: Color(0xFF202020)),
      );

      expect(themed.colorScheme.primary, const Color(0xFFFFD54F));
      expect(themed.colorScheme.onPrimary, Colors.black);  // chữ trên nền vàng sáng phải tối
      expect(themed.scaffoldBackgroundColor, const Color(0xFF101010));
      expect(themed.bottomNavigationBarTheme.backgroundColor, const Color(0xFF202020));
    });

    test('cấu hình trống giữ nguyên theme', () {
      final themed = AppTheme.applyConfig(AppTheme.lightTheme, const ThemeConfig());

      expect(themed.colorScheme.primary, AppTheme.lightTheme.colorScheme.primary);
      expect(themed.scaffoldBackgroundColor, AppTheme.lightTheme.scaffoldBackgroundColor);
    });

    test('font không tải được thì giữ font hiện tại thay vì làm hỏng theme', () {
      final themed = AppTheme.applyConfig(AppTheme.darkTheme, const ThemeConfig(fontFamily: 'Font Không Tồn Tại'));

      expect(themed.textTheme.bodyMedium?.fontFamily, AppTheme.darkTheme.textTheme.bodyMedium?.fontFamily);
    });
  });
}
