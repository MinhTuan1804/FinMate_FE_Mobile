import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/network/native_token_storage.dart';
import 'package:finmate/core/network/token_storage.dart';

class _StubAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  _StubAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _html(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );

Never _networkDown(RequestOptions o) =>
    throw DioException(requestOptions: o, type: DioExceptionType.connectionError);

class _NativeStorage extends InMemoryTokenStorage implements NativeRefresher {
  _NativeStorage(NativeRefreshResult this._result) : _error = null;
  _NativeStorage.throwing(Object this._error) : _result = null;

  final NativeRefreshResult? _result;
  final Object? _error;
  final List<String?> staleTokens = [];

  @override
  Future<NativeRefreshResult> refreshViaNative({String? staleAccessToken}) async {
    staleTokens.add(staleAccessToken);
    if (_error != null) throw _error;
    return _result!;
  }
}

void main() {
  late InMemoryTokenStorage storage;
  late int expiredCount;

  ApiClient buildClient(_StubAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    return ApiClient(tokenStorage: storage, customDio: dio, onSessionExpired: () => expiredCount++);
  }

  setUp(() async {
    storage = InMemoryTokenStorage();
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    expiredCount = 0;
  });

  group('ApiClient - phản hồi không phải JSON', () {
    test('200 trả về HTML (trang cảnh báo của tunnel) -> ApiException thân thiện, không phải lỗi ép kiểu', () async {
      final client = buildClient(_StubAdapter((_) => _html('<html>ngrok</html>', 200)));

      await expectLater(
        client.get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE')),
      );
    });

    test('502 trả về HTML -> thông điệp lỗi máy chủ bằng tiếng Việt', () async {
      final client = buildClient(_StubAdapter((_) => _html('<html>Bad gateway</html>', 502)));

      await expectLater(
        client.get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Máy chủ đang gặp sự cố'))),
      );
    });
  });

  group('ApiClient - phản hồi thành công không có nội dung (204)', () {
    test('204 rỗng (như resend-verification) không bị coi là dữ liệu không hợp lệ', () async {
      final client = buildClient(_StubAdapter((_) => ResponseBody.fromString('', 204)));

      final response = await client.post('/api/v1/auth/resend-verification', data: {'email': 'a@b.com'}, fromJsonT: (j) => j);

      expect(response.data, isNull);
      expect(response.errors, isEmpty);
    });

    test('200 với body rỗng cũng chấp nhận; 200 với HTML vẫn là lỗi', () async {
      final empty = buildClient(_StubAdapter((_) => ResponseBody.fromString('', 200)));
      expect((await empty.get('/x', fromJsonT: (j) => j)).data, isNull);

      final html = buildClient(_StubAdapter((_) => _html('<html/>', 200)));
      await expectLater(html.get('/x', fromJsonT: (j) => j), throwsA(isA<ApiException>()));
    });
  });

  group('ApiClient - chi tiết lỗi validation của backend', () {
    test('error.details[].message được nối vào thông điệp', () async {
      final client = buildClient(_StubAdapter((_) => _json({
            'success': false,
            'data': null,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Dữ liệu không hợp lệ.',
              'details': [
                {'field': 'AmountCents', 'message': 'Số tiền phải lớn hơn 0.'},
              ],
            },
          }, 400)));

      await expectLater(
        client.post('/api/v1/transactions', data: {}, fromJsonT: (j) => j),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')
            .having((e) => e.message, 'message', 'Dữ liệu không hợp lệ. Số tiền phải lớn hơn 0.')),
      );
    });
  });

  group('ApiClient - lỗi validation (ProblemDetails)', () {
    test('errors dạng map -> thông điệp "Dữ liệu không hợp lệ" kèm chi tiết', () async {
      final client = buildClient(_StubAdapter((_) => _json({
            'title': 'One or more validation errors occurred.',
            'status': 400,
            'errors': {
              'request': ['The request field is required.'],
            },
          }, 400)));

      await expectLater(
        client.post('/api/v1/transactions', data: {}, fromJsonT: (j) => j),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION')
            .having((e) => e.message, 'message', startsWith('Dữ liệu không hợp lệ'))),
      );
    });
  });

  group('ApiClient - lỗi nghiệp vụ từ backend', () {
    test('Đọc thông điệp từ {"error": {code, message}} (định dạng thật của FinMate.API)', () async {
      final client = buildClient(_StubAdapter((_) => _json({
            'success': false,
            'data': null,
            'error': {'code': 'AUTH_INVALID_OTP', 'message': 'Mã xác thực không đúng.', 'details': null},
          }, 400)));

      await expectLater(
        client.post('/api/v1/auth/verify-email', data: {}, fromJsonT: (j) => j),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'AUTH_INVALID_OTP')
            .having((e) => e.message, 'message', 'Mã xác thực không đúng.')),
      );
    });

    test('Đăng nhập sai: dùng thông điệp của server', () async {
      final client = buildClient(_StubAdapter((_) => _json({
            'success': false,
            'data': null,
            'error': {'code': 'AUTH_INVALID_CREDENTIALS', 'message': 'Email hoặc mật khẩu không đúng.'},
          }, 401)));

      await expectLater(
        client.post('/api/v1/auth/login', data: {}, fromJsonT: (j) => j),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email hoặc mật khẩu không đúng.')),
      );
    });
  });

  group('AuthInterceptor', () {
    test('Đăng nhập sai (401): báo sai thông tin, không refresh, không coi là hết phiên', () async {
      final adapter = _StubAdapter((_) => _json({'errors': []}, 401));
      final client = buildClient(adapter);

      await expectLater(
        client.post('/api/v1/auth/login', data: {}, fromJsonT: (j) => j),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email hoặc mật khẩu không chính xác.')),
      );
      expect(adapter.requests.where((r) => r.path.contains('/auth/refresh')), isEmpty);
      expect(expiredCount, 0);
      expect(await storage.getRefreshToken(), 'r1');
    });

    test('401 trên API bảo vệ: refresh thành công rồi gửi lại request với token mới', () async {
      final adapter = _StubAdapter((o) {
        if (o.path.contains('/auth/refresh')) {
          return _json({'data': {'accessToken': 'new', 'refreshToken': 'r2'}}, 200);
        }
        return o.headers['Authorization'] == 'Bearer new'
            ? _json({'data': {'ok': true}}, 200)
            : _json({'errors': []}, 401);
      });
      final client = buildClient(adapter);

      final response = await client.get('/api/v1/users/me', fromJsonT: (j) => j);

      expect((response.data as Map)['ok'], isTrue);
      expect(await storage.getAccessToken(), 'new');
      expect(await storage.getRefreshToken(), 'r2');
      expect(expiredCount, 0);
    });

    test('Lỗi mạng khi refresh: giữ nguyên phiên, không đăng xuất', () async {
      final client = buildClient(_StubAdapter((o) {
        if (o.path.contains('/auth/refresh')) _networkDown(o);
        return _json({'errors': []}, 401);
      }));

      await expectLater(
        client.get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<NetworkException>()),
      );
      expect(expiredCount, 0);
      expect(await storage.getRefreshToken(), 'r1');
    });

    test('Refresh bị từ chối (401): xóa token và báo hết phiên', () async {
      final client = buildClient(_StubAdapter((_) => _json({'errors': []}, 401)));

      await expectLater(
        client.get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<ApiException>()),
      );
      expect(expiredCount, 1);
      expect(await storage.getAccessToken(), isNull);
    });
  });

  group('AuthInterceptor + NativeRefresher', () {
    late _NativeStorage nativeStorage;

    ApiClient buildNativeClient(_StubAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
      return ApiClient(tokenStorage: nativeStorage, customDio: dio, onSessionExpired: () => expiredCount++);
    }

    Future<void> seed(_NativeStorage s) => s.saveTokens(accessToken: 'old', refreshToken: 'r1');

    test('native ok: gửi lại request với token mới, không gọi /auth/refresh qua Dio, native nhận token cũ', () async {
      nativeStorage = _NativeStorage(const NativeRefreshResult(NativeRefreshStatus.ok, 'new'));
      await seed(nativeStorage);
      final adapter = _StubAdapter((o) => o.headers['Authorization'] == 'Bearer new'
          ? _json({'data': {'ok': true}}, 200)
          : _json({'errors': []}, 401));

      final response = await buildNativeClient(adapter).get('/api/v1/users/me', fromJsonT: (j) => j);

      expect((response.data as Map)['ok'], isTrue);
      expect(adapter.requests.where((r) => r.path.contains('/auth/refresh')), isEmpty);
      expect(nativeStorage.staleTokens, ['old']);
      expect(expiredCount, 0);
    });

    test('native expired: xóa token và báo hết phiên đúng 1 lần', () async {
      nativeStorage = _NativeStorage(const NativeRefreshResult(NativeRefreshStatus.expired));
      await seed(nativeStorage);

      await expectLater(
        buildNativeClient(_StubAdapter((_) => _json({'errors': []}, 401))).get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<ApiException>()),
      );
      expect(expiredCount, 1);
      expect(await nativeStorage.getAccessToken(), isNull);
    });

    test('native network: NetworkException, giữ phiên', () async {
      nativeStorage = _NativeStorage(const NativeRefreshResult(NativeRefreshStatus.network));
      await seed(nativeStorage);

      await expectLater(
        buildNativeClient(_StubAdapter((_) => _json({'errors': []}, 401))).get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<NetworkException>()),
      );
      expect(expiredCount, 0);
      expect(await nativeStorage.getRefreshToken(), 'r1');
    });

    test('native ném lỗi (PlatformException): coi là lỗi tạm thời, giữ phiên', () async {
      nativeStorage = _NativeStorage.throwing(PlatformException(code: 'boom'));
      await seed(nativeStorage);

      await expectLater(
        buildNativeClient(_StubAdapter((_) => _json({'errors': []}, 401))).get('/api/v1/users/me', fromJsonT: (j) => j),
        throwsA(isA<NetworkException>()),
      );
      expect(expiredCount, 0);
      expect(await nativeStorage.getAccessToken(), 'old');
      expect(await nativeStorage.getRefreshToken(), 'r1');
    });
  });

  test('tải ảnh lên (quét hóa đơn) được chờ lâu hơn các lệnh thường: OCR mất 5-35 giây, 15 giây làm app báo mất mạng dù backend vẫn xử lý xong', () async {
    final adapter = _StubAdapter((_) => _json({'success': true, 'data': {}}, 200));
    final client = ApiClient(
      tokenStorage: InMemoryTokenStorage(),
      customDio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );

    await client.uploadFile('/api/v1/transactions/scan-receipt', formData: FormData.fromMap({'file': 'x'}), fromJsonT: (j) => j);
    await client.get('/api/v1/users/me', fromJsonT: (j) => j);

    final upload = adapter.requests.first;
    expect(upload.receiveTimeout!, greaterThanOrEqualTo(const Duration(seconds: 60)));
    expect(upload.sendTimeout, greaterThanOrEqualTo(const Duration(seconds: 60)));
    expect(adapter.requests.last.receiveTimeout, isNull); // lệnh thường giữ cấu hình chung (15 giây khi chạy thật)
  });
}
