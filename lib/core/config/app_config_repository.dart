import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Nơi giữ bản cấu hình cuối cùng tải được, để mở app lúc mất mạng vẫn đúng giao diện và vẫn biết đang bảo trì.
abstract class AppConfigStore {
  Future<String?> read();
  Future<void> write(String raw);
}

/// Một file JSON nhỏ trong thư mục hỗ trợ của app. Cấu hình không bí mật (màu, chữ, lời nhắn bảo trì) nên không cần kho mã hóa.
class FileAppConfigStore implements AppConfigStore {
  Future<File> _file() async => File(p.join((await getApplicationSupportDirectory()).path, 'app_config.json'));

  @override
  Future<String?> read() async {
    try {
      final file = await _file();
      return await file.exists() ? await file.readAsString() : null;
    } on Object {
      return null;  // không đọc được bản đệm thì coi như chưa có, không phải lỗi
    }
  }

  @override
  Future<void> write(String raw) async {
    try {
      await (await _file()).writeAsString(raw, flush: true);
    } on Object {
      // bản đệm chỉ là tiện ích: ghi hỏng không được làm hỏng việc tải cấu hình
    }
  }
}

class AppConfigRepository {
  AppConfigRepository({required this.apiClient, required this.store});

  final ApiClient apiClient;
  final AppConfigStore store;

  static const String path = '/api/v1/app-config';

  Future<AppConfig?> cached() async {
    final raw = await store.read();
    if (raw == null) return null;
    try {
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// Tải bản mới nhất (công khai, không cần đăng nhập) và lưu làm bản đệm. Ném lỗi mạng/phản hồi như mọi lời gọi API; người gọi quyết định bỏ qua.
  Future<AppConfig> fetch() async {
    final response = await apiClient.get<Map<String, dynamic>>(path, fromJsonT: (json) => json as Map<String, dynamic>);
    final data = response.data;
    if (data == null) throw StateError('app-config rỗng');
    await store.write(jsonEncode(data));
    return AppConfig.fromJson(data);
  }
}

final appConfigStoreProvider = Provider<AppConfigStore>((ref) => FileAppConfigStore());

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(apiClient: ref.watch(apiClientProvider), store: ref.watch(appConfigStoreProvider)),
);
