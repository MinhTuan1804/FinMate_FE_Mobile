import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_response.dart';
import 'package:finmate/core/network/token_storage.dart';

void main() {
  group('Core Network - ApiResponse Parser Test', () {
    test('Parse thành công response đơn lẻ', () {
      final json = {
        'data': {'id': '123', 'email': 'test@finmate.com'},
        'meta': null,
        'errors': []
      };

      final response = ApiResponse.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(response.isSuccess, isTrue);
      expect(response.data!['id'], '123');
      expect(response.data!['email'], 'test@finmate.com');
      expect(response.meta, isNull);
      expect(response.errors, isEmpty);
    });

    test('Parse thành công response danh sách kèm cursor phân trang', () {
      final json = {
        'data': ['item1', 'item2'],
        'meta': {'nextCursor': 'cursor_123'},
        'errors': []
      };

      final response = ApiResponse.fromJson(
        json,
        (data) => (data as List).map((e) => e.toString()).toList(),
      );

      expect(response.isSuccess, isTrue);
      expect(response.data!.length, 2);
      expect(response.meta?.nextCursor, 'cursor_123');
    });

    test('Parse meta.cursor thật của backend (và nextCursor cũ)', () {
      expect(ApiMeta.fromJson({'cursor': 'c1'}).nextCursor, 'c1');
      expect(ApiMeta.fromJson({'nextCursor': 'c2'}).nextCursor, 'c2');
      expect(ApiMeta.fromJson({'cursor': null}).nextCursor, isNull);
    });

    test('Parse lỗi nghiệp vụ BusinessRuleException', () {
      final json = {
        'data': null,
        'meta': null,
        'errors': [
          {'code': 'INSUFFICIENT_FUNDS', 'message': 'Số dư tài khoản không đủ.'}
        ]
      };

      final response = ApiResponse<dynamic>.fromJson(json, (data) => data);
      expect(response.isSuccess, isFalse);
      expect(response.errors.first.code, 'INSUFFICIENT_FUNDS');
      expect(response.errors.first.message, 'Số dư tài khoản không đủ.');
    });
  });

  group('Core Network - TokenStorage In-Memory Fallback Test', () {
    test('TokenStorage lưu, đọc và xóa token chuẩn xác', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'access_123', refreshToken: 'refresh_456');

      expect(await storage.getAccessToken(), 'access_123');
      expect(await storage.getRefreshToken(), 'refresh_456');
      expect(await storage.hasAccessToken(), isTrue);

      await storage.clearTokens();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.hasAccessToken(), isFalse);
    });
  });
}
