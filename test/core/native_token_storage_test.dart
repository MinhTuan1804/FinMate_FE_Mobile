import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/network/native_token_storage.dart';
import 'package:finmate/core/network/token_storage.dart';

const _channel = MethodChannel('com.example.finmate/notifications');

class _ThrowOnceClearStorage extends InMemoryTokenStorage {
  bool _thrown = false;

  @override
  Future<void> clearTokens() async {
    if (!_thrown) {
      _thrown = true;
      throw StateError('keystore');
    }
    await super.clearTokens();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Map<String, Object? Function(MethodCall)> handlers;

  setUp(() {
    calls = [];
    handlers = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final h = handlers[call.method];
      return h == null ? null : h(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  NativeTokenStorage build(ITokenStorage legacy) => NativeTokenStorage(
        bridge: NotificationBridge(),
        legacy: legacy,
        baseUrl: 'http://api.test',
      );

  test('saveTokens_calls_setSession_with_baseUrl', () async {
    handlers['getAccessToken'] = (_) => 'x'; // đã có token native, không di chuyển
    await build(InMemoryTokenStorage())
        .saveTokens(accessToken: 'a1', refreshToken: 'r1');
    final c = calls.singleWhere((c) => c.method == 'setSession');
    expect(c.arguments,
        {'baseUrl': 'http://api.test', 'accessToken': 'a1', 'refreshToken': 'r1'});
  });

  test('getAccessToken_reads_native', () async {
    handlers['getAccessToken'] = (_) => 'native-token';
    handlers['getRefreshToken'] = (_) => 'native-refresh';
    final s = build(InMemoryTokenStorage());
    expect(await s.getAccessToken(), 'native-token');
    expect(await s.getRefreshToken(), 'native-refresh');
    expect(await s.hasAccessToken(), isTrue);
  });

  test('clearTokens_clears_native_and_legacy', () async {
    final legacy = InMemoryTokenStorage();
    handlers['getAccessToken'] = (_) => 'x';
    await legacy.saveTokens(accessToken: 'la', refreshToken: 'lr');
    await build(legacy).clearTokens();
    expect(calls.any((c) => c.method == 'clearSession'), isTrue);
    expect(await legacy.getAccessToken(), isNull);
  });

  test('first_use_migrates_legacy_tokens_when_native_empty_then_clears_legacy',
      () async {
    final legacy = InMemoryTokenStorage();
    await legacy.saveTokens(accessToken: 'la', refreshToken: 'lr');
    String? nativeAccess;
    handlers['getAccessToken'] = (_) => nativeAccess;
    handlers['setSession'] = (c) {
      nativeAccess = (c.arguments as Map)['accessToken'] as String;
      return null;
    };
    final s = build(legacy);
    expect(await s.getAccessToken(), 'la');
    expect(await s.getAccessToken(), 'la');
    final sets = calls.where((c) => c.method == 'setSession').toList();
    expect(sets, hasLength(1)); // đúng một lần
    expect(sets.single.arguments,
        {'baseUrl': 'http://api.test', 'accessToken': 'la', 'refreshToken': 'lr'});
    expect(await legacy.getAccessToken(), isNull);
  });

  test('no_migration_when_native_already_has_token', () async {
    final legacy = InMemoryTokenStorage();
    await legacy.saveTokens(accessToken: 'la', refreshToken: 'lr');
    handlers['getAccessToken'] = (_) => 'native';
    final s = build(legacy);
    expect(await s.getAccessToken(), 'native');
    expect(calls.any((c) => c.method == 'setSession'), isFalse);
    // Token cũ đã bị xoay: xóa luôn để sau này không bị chép lại và dùng lại refresh token đã thu hồi.
    expect(await legacy.getAccessToken(), isNull);
  });

  test('legacy_clear_failure_after_setSession_does_not_fail_or_remigrate',
      () async {
    final legacy = _ThrowOnceClearStorage();
    await legacy.saveTokens(accessToken: 'la', refreshToken: 'lr');
    String? nativeAccess;
    handlers['getAccessToken'] = (_) => nativeAccess;
    handlers['setSession'] = (c) {
      nativeAccess = (c.arguments as Map)['accessToken'] as String;
      return null;
    };
    expect(await build(legacy).getAccessToken(), 'la'); // không ném dù clear lỗi
    expect(await legacy.getAccessToken(), 'la'); // lần clear đầu đã lỗi
    // Instance mới (lần mở app sau): native đã có token -> chỉ dọn legacy, không setSession lại.
    expect(await build(legacy).getAccessToken(), 'la');
    expect(calls.where((c) => c.method == 'setSession'), hasLength(1));
    expect(await legacy.getAccessToken(), isNull);
  });

  test('refreshViaNative_maps_ok_expired_network_and_passes_staleAccessToken',
      () async {
    handlers['getAccessToken'] = (_) => 'x';
    Object? reply;
    handlers['refreshSession'] = (_) => reply;
    final s = build(InMemoryTokenStorage());

    reply = {'status': 'ok', 'accessToken': 'new'};
    var r = await s.refreshViaNative(staleAccessToken: 'old');
    expect(r.status, NativeRefreshStatus.ok);
    expect(r.accessToken, 'new');
    expect(calls.last.arguments, {'staleAccessToken': 'old'});

    reply = {'status': 'expired'};
    r = await s.refreshViaNative();
    expect(r.status, NativeRefreshStatus.expired);
    expect(r.accessToken, isNull);

    reply = {'status': 'network'};
    expect((await s.refreshViaNative()).status, NativeRefreshStatus.network);
  });

  test('bridge_swallows_MissingPluginException_with_safe_defaults', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null); // không có plugin
    final b = NotificationBridge();
    await b.flushQueue();
    await b.setSession(baseUrl: 'u', accessToken: 'a', refreshToken: 'r');
    await b.clearSession();
    await b.setMonitoredPackages(['p']);
    await b.openNotificationAccessSettings();
    expect(await b.isNotificationAccessEnabled(), isFalse);
    expect(await b.consumeSessionExpired(), isFalse);
    expect(await b.getAccessToken(), isNull);
    expect(await b.getRefreshToken(), isNull);
    expect((await b.refreshSession()).status, NativeRefreshStatus.network);
  });

  test('bridge_serializes_mutating_calls_in_call_order_without_awaiting',
      () async {
    final log = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      log.add('${call.method}:start');
      if (call.method == 'clearSession') {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      log.add('${call.method}:end');
      return null;
    });
    final b = NotificationBridge();
    final f1 = b.clearSession();
    final f2 =
        b.setSession(baseUrl: 'u', accessToken: 'a', refreshToken: 'r');
    final f3 = b.setMonitoredPackages(['p']);
    await Future.wait([f1, f2, f3]);
    expect(log, [
      'clearSession:start',
      'clearSession:end',
      'setSession:start',
      'setSession:end',
      'setMonitoredPackages:start',
      'setMonitoredPackages:end',
    ]);
  });

  test('bridge_chain_survives_a_failed_mutating_call', () async {
    handlers['clearSession'] =
        (_) => throw PlatformException(code: 'native_error');
    final b = NotificationBridge();
    final f1 = b.clearSession();
    final f2 =
        b.setSession(baseUrl: 'u', accessToken: 'a', refreshToken: 'r');
    await expectLater(f1, throwsA(isA<PlatformException>()));
    await f2;
    expect(calls.map((c) => c.method), ['clearSession', 'setSession']);
  });
}
