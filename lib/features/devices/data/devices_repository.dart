import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Đăng ký/gỡ token FCM của thiết bị hiện tại để nhận push. Giá trị [platform] đúng tên enum BE:
/// 'Android' | 'Ios' | 'Web' (JsonStringEnumConverter toàn cục, không viết thường như QrTransferStatus).
class DevicesRepository {
  final ApiClient apiClient;

  DevicesRepository({required this.apiClient});

  /// Gọi mỗi lần mở app (FCM có thể cấp token mới bất cứ lúc nào). Token đã tồn tại thì BE
  /// tự chuyển chủ sang user hiện tại (không tạo dòng mới) — an toàn khi nhiều người dùng chung máy.
  Future<void> registerDevice({required String token, required String platform}) async {
    await apiClient.post(
      '/api/v1/devices',
      data: {'token': token, 'platform': platform},
      fromJsonT: (json) => json,
    );
  }

  /// Gọi khi đăng xuất khỏi thiết bị này (không ảnh hưởng thiết bị khác).
  Future<void> unregisterDevice(String token) async {
    await apiClient.delete('/api/v1/devices', data: {'token': token});
  }
}
