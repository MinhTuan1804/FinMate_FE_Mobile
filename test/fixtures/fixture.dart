import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/token_storage.dart';

/// ApiClient chạy trên adapter giả (không đụng mạng thật).
ApiClient testApiClient(HttpClientAdapter adapter, {ITokenStorage? storage, void Function()? onSessionExpired}) {
  return ApiClient(
    tokenStorage: storage ?? InMemoryTokenStorage(),
    customDio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    onSessionExpired: onSessionExpired,
  );
}

/// Đọc response thật của backend đã lưu ở test/fixtures/api/NAME.json (dạng envelope đầy đủ).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// Phần `data` của một fixture.
dynamic fixtureData(String name) => fixture(name)['data'];

/// Adapter HTTP giả: định tuyến theo (method, path) tới một handler; ghi lại các request đã gửi.
class RouteAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  /// Độ trễ mạng giả cho từng request (mặc định không trễ): máy thật luôn có độ trễ, nên giữa lúc "đang lưu" và lúc có phản hồi
  /// Flutter vẽ thêm khung hình; phản hồi tức thì che mất loại lỗi phụ thuộc thứ tự đó.
  final Duration Function(RequestOptions options)? delayOf;
  final List<RequestOptions> requests = [];

  RouteAdapter(this.handler, {this.delayOf});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final delay = delayOf?.call(options);
    if (delay != null && delay > Duration.zero) await Future<void>.delayed(delay);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  /// Các request đã gửi tới path chứa [fragment].
  Iterable<RequestOptions> to(String fragment) => requests.where((r) => r.path.contains(fragment));
}

/// Trả về một fixture làm phản hồi HTTP.
ResponseBody respondFixture(String name, {int status = 200}) => respondJson(fixture(name), status: status);

ResponseBody respondJson(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Never throwNetworkDown(RequestOptions o) =>
    throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
